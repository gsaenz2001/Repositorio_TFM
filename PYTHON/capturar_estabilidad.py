import os
import re
import time
import uuid
import queue
import threading
import subprocess
import serial

# ===================== CONFIGURACIÓN =====================
PORT = "COM3"
BAUD = 115200
TIMEOUT_S = 2.0
NUM_MUESTRAS = 500

# Nombre del archivo final
OUTPUT_FILE = r"ESTABILIDAD\M1_1L_3.txt"

# Carpeta con los .bit
BITSTREAM_DIR = r"D:\TFM\VIVADO\Testbench_4RO"

# Ruta a Vivado
VIVADO_BAT = r"D:\XILINX_2023.1\Vivado\2023.1\bin\vivado.bat"

# Espera tras programar la FPGA
# Puedes bajarla a 0.2 o 0.0 si ves que la placa arranca rápido
POST_PROGRAM_DELAY_S = 0.5

# Orden de ejecución
VENTANAS = ["100ms", "10ms", "1ms", "100us"]
ETAPAS = [3, 5, 51, 101]
# ========================================================


def ensure_output_dir(filepath: str):
    folder = os.path.dirname(filepath)
    if folder:
        os.makedirs(folder, exist_ok=True)


def parse_freqs_line(line: str):
    """
    Espera una línea con 4 números, por ejemplo:
    123456789,123456780,123456781,123456782
    """
    s = line.strip()
    if not s:
        return None

    nums = re.findall(r"\d+", s)
    if len(nums) < 4:
        return None

    try:
        return [int(nums[0]), int(nums[1]), int(nums[2]), int(nums[3])]
    except ValueError:
        return None


def build_bitstream_path(ventana: str, etapas: int):
    return os.path.join(BITSTREAM_DIR, f"{ventana}_{etapas}etapas.bit")


def validate_paths():
    if not os.path.exists(VIVADO_BAT):
        raise FileNotFoundError(f"No existe vivado.bat: {VIVADO_BAT}")

    for ventana in VENTANAS:
        for etapas in ETAPAS:
            bitstream = build_bitstream_path(ventana, etapas)
            if not os.path.exists(bitstream):
                raise FileNotFoundError(f"No existe el bitstream: {bitstream}")


def write_block_header(f, ventana: str, etapas: int, bitstream_path: str):
    f.write("\n")
    f.write("============================================================\n")
    f.write(f"# BITSTREAM: {os.path.basename(bitstream_path)}\n")
    f.write(f"# VENTANA: {ventana}\n")
    f.write(f"# ETAPAS_PRINCIPAL: {etapas}\n")
    f.write(f"# NUM_MUESTRAS: {NUM_MUESTRAS}\n")
    f.write("# FORMATO: idx\tfreq1_hz\tfreq2_hz\tfreq3_hz\tfreq4_hz\n")
    f.write("============================================================\n")
    f.write("idx\tfreq1_hz\tfreq2_hz\tfreq3_hz\tfreq4_hz\n")


def wait_for_first_valid_line(ser, max_wait_s=5.0):
    t0 = time.time()
    while time.time() - t0 < max_wait_s:
        raw = ser.readline()
        if not raw:
            continue

        line = raw.decode("utf-8", errors="ignore")
        freqs = parse_freqs_line(line)
        if freqs is not None:
            return freqs

    return None


def capture_block(ser, f, ventana: str, etapas: int, bitstream_path: str):
    write_block_header(f, ventana, etapas, bitstream_path)

    ser.reset_input_buffer()

    first = wait_for_first_valid_line(ser, max_wait_s=5.0)
    if first is None:
        raise RuntimeError(
            f"No llegaron datos válidos tras programar {os.path.basename(bitstream_path)}"
        )

    count = 0
    f.write(f"{count}\t{first[0]}\t{first[1]}\t{first[2]}\t{first[3]}\n")
    count += 1

    while count < NUM_MUESTRAS:
        raw = ser.readline()
        if not raw:
            continue

        line = raw.decode("utf-8", errors="ignore")
        freqs = parse_freqs_line(line)
        if freqs is None:
            continue

        f.write(f"{count}\t{freqs[0]}\t{freqs[1]}\t{freqs[2]}\t{freqs[3]}\n")
        count += 1

        if count % 100 == 0:
            print(
                f"[{ventana} - {etapas} etapas] "
                f"{count}/{NUM_MUESTRAS} -> "
                f"{freqs[0]}, {freqs[1]}, {freqs[2]}, {freqs[3]}"
            )

    f.flush()


class VivadoSession:
    """
    Mantiene una sesión Tcl persistente de Vivado abierta.
    """

    def __init__(self, vivado_bat: str):
        self.vivado_bat = vivado_bat
        self.proc = None
        self.stdout_queue = queue.Queue()
        self.reader_thread = None

    def start(self):
        cmd = [
            self.vivado_bat,
            "-mode", "tcl",
            "-nojournal",
            "-nolog",
            "-notrace",
        ]

        print("Abriendo sesión persistente de Vivado...")
        self.proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )

        self.reader_thread = threading.Thread(
            target=self._reader_loop,
            daemon=True,
        )
        self.reader_thread.start()

        # Sincronización inicial
        self._send_and_wait('puts "__PY_VIVADO_READY__"', "__PY_VIVADO_READY__", timeout=120.0)

        # Inicialización hardware una sola vez
        init_tcl = r'''
open_hw_manager
connect_hw_server
open_hw_target

set dev [lindex [get_hw_devices] 0]
if {$dev eq ""} {
    error "No se ha encontrado ningún dispositivo hardware."
}

current_hw_device $dev
refresh_hw_device $dev
puts "__PY_HW_INIT_OK__"
'''
        self._send_and_wait(init_tcl, "__PY_HW_INIT_OK__", timeout=120.0)
        print("Sesión Vivado lista.")

    def close(self):
        if self.proc is None:
            return

        try:
            self.send("exit")
        except Exception:
            pass

        try:
            self.proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.proc.kill()

        self.proc = None

    def send(self, tcl: str):
        if self.proc is None or self.proc.stdin is None:
            raise RuntimeError("La sesión Vivado no está iniciada.")

        self.proc.stdin.write(tcl + "\n")
        self.proc.stdin.flush()

    def _reader_loop(self):
        if self.proc is None or self.proc.stdout is None:
            return

        for line in self.proc.stdout:
            clean = line.rstrip("\n")
            print(f"[VIVADO] {clean}")
            self.stdout_queue.put(clean)

    def _send_and_wait(self, tcl: str, marker: str, timeout=120.0):
        self.send(tcl)

        deadline = time.time() + timeout
        collected = []

        while time.time() < deadline:
            try:
                line = self.stdout_queue.get(timeout=0.5)
                collected.append(line)

                if marker in line:
                    return collected

                # Si Vivado emite un error Tcl claro, abortamos
                low = line.lower()
                if low.startswith("error:") or "no se ha encontrado ningún dispositivo" in low:
                    raise RuntimeError("Vivado devolvió un error:\n" + "\n".join(collected[-50:]))

            except queue.Empty:
                # Verificar si el proceso ha muerto
                if self.proc.poll() is not None:
                    raise RuntimeError("La sesión de Vivado terminó inesperadamente.")
                continue

        raise TimeoutError(
            f"Timeout esperando marcador '{marker}'. "
            f"Últimas líneas:\n" + "\n".join(collected[-50:])
        )

    def program_bitstream(self, bitstream_path: str, timeout=180.0):
        if not os.path.exists(bitstream_path):
            raise FileNotFoundError(f"No existe el bitstream: {bitstream_path}")

        marker = f"__PY_PROGRAM_DONE_{uuid.uuid4().hex}__"

        # Importante: usar ruta con barras / para Tcl
        bit_tcl = bitstream_path.replace("\\", "/")

        tcl = f'''
set dev [lindex [get_hw_devices] 0]
if {{$dev eq ""}} {{
    error "No se ha encontrado ningún dispositivo hardware."
}}

current_hw_device $dev
refresh_hw_device $dev

set_property PROGRAM.FILE {{{bit_tcl}}} $dev
program_hw_devices $dev
refresh_hw_device $dev

puts "{marker}"
'''

        print(f"Programando FPGA con: {os.path.basename(bitstream_path)}")
        self._send_and_wait(tcl, marker, timeout=timeout)


def main():
    ensure_output_dir(OUTPUT_FILE)
    validate_paths()

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("# CAPTURA AUTOMATICA MULTIBITSTREAM\n")
        f.write(f"# Puerto serie: {PORT}\n")
        f.write(f"# Baudrate: {BAUD}\n")
        f.write(f"# Muestras por bitstream: {NUM_MUESTRAS}\n")
        f.write("# Orden: 100ms -> 10ms -> 1ms -> 100us ; etapas 3, 5, 51, 101\n")

    vivado = VivadoSession(VIVADO_BAT)

    try:
        vivado.start()

        with serial.Serial(PORT, BAUD, timeout=TIMEOUT_S) as ser, \
             open(OUTPUT_FILE, "a", encoding="utf-8") as f:

            total = len(VENTANAS) * len(ETAPAS)
            current = 0

            for ventana in VENTANAS:
                for etapas in ETAPAS:
                    current += 1
                    bitstream_path = build_bitstream_path(ventana, etapas)

                    print("\n" + "=" * 70)
                    print(f"Configuración {current}/{total}")
                    print(f"Ventana : {ventana}")
                    print(f"Etapas  : {etapas}")
                    print(f"Archivo : {bitstream_path}")

                    vivado.program_bitstream(bitstream_path)

                    if POST_PROGRAM_DELAY_S > 0:
                        print(f"Esperando {POST_PROGRAM_DELAY_S} s tras la programación...")
                        time.sleep(POST_PROGRAM_DELAY_S)

                    capture_block(ser, f, ventana, etapas, bitstream_path)

    finally:
        vivado.close()

    print("\nProceso completado.")
    print(f"Datos guardados en: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()