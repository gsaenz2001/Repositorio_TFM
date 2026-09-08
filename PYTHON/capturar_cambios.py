import os
import re
import time
import uuid
import queue
import threading
import subprocess
from datetime import datetime

import serial

# ===================== CONFIGURACIÓN =====================

PORT = "COM3"
BAUD = 115200
TIMEOUT_S = 2.0

# Número fijo de muestras por bloque
NUM_SAMPLES = 500

# Tiempo máximo esperando la primera muestra válida tras programar
MAX_WAIT_FIRST_VALID_S = 5.0

# Tiempo máximo permitido para capturar un bloque completo
MAX_BLOCK_DURATION_S = 60.0

# Carpeta de salida
OUTPUT_DIR = r"CONDICONES_AMBIENTALES_M2_2L_16"

# PCBs seleccionadas tras el estudio de estabilidad
PCBS_A_MEDIR = [
   # "M1_2L_4",
   # "M2_2L_4_06",
   # "M2_2L_4_10",
    "M2_2L_4_16"
   # "M3_2L_5",
   # "M4_2L_5",
   # "M5_2L_4",
]

# Carpeta con los .bit
BITSTREAM_DIR = r"D:\TFM\VIVADO\Testbench_4RO"

# Ruta a Vivado
VIVADO_BAT = r"D:\XILINX_2023.1\Vivado\2023.1\bin\vivado.bat"

# Espera tras programar la FPGA
POST_PROGRAM_DELAY_S = 0.5

# Orden de ejecución
VENTANAS = ["100ms", "10ms", "1ms", "100us"]
ETAPAS = [3, 5, 51, 101]

# Condiciones descartadas tras el estudio de estabilidad
CONDICIONES_DESCARTADAS = {
    ("100ms", 3),
}

# Estados de medida con la sonda
ESTADOS_SONDA = [
    ("SIN_SONDA", "Retira la sonda de la PCB."),
    ("SONDA_P1", "Coloca la sonda sobre la pista 1."),
    ("SONDA_P2", "Coloca la sonda sobre la pista 2."),
    ("SONDA_P3", "Coloca la sonda sobre la pista 3."),
    ("SONDA_P4", "Coloca la sonda sobre la pista 4."),
]

# =========================================================


def ensure_dir(folder: str):
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


def get_valid_conditions():
    conditions = []
    for ventana in VENTANAS:
        for etapas in ETAPAS:
            if (ventana, etapas) in CONDICIONES_DESCARTADAS:
                continue
            conditions.append((ventana, etapas))
    return conditions


def validate_paths():
    if not os.path.exists(VIVADO_BAT):
        raise FileNotFoundError(f"No existe vivado.bat: {VIVADO_BAT}")

    for ventana, etapas in get_valid_conditions():
        bitstream = build_bitstream_path(ventana, etapas)
        if not os.path.exists(bitstream):
            raise FileNotFoundError(f"No existe el bitstream: {bitstream}")


def estado_to_posicion(estado_sonda: str):
    if estado_sonda == "SIN_SONDA":
        return "NINGUNA"
    return estado_sonda.replace("SONDA_", "")


def write_file_header(f, pcb: str):
    f.write("# CAPTURA AUTOMATICA MULTIBITSTREAM CON SONDA\n")
    f.write(f"# FECHA_INICIO: {datetime.now().isoformat(timespec='seconds')}\n")
    f.write(f"# PCB: {pcb}\n")
    f.write(f"# Puerto serie: {PORT}\n")
    f.write(f"# Baudrate: {BAUD}\n")
    f.write(f"# NUM_SAMPLES: {NUM_SAMPLES}\n")
    f.write("# Estados de sonda: SIN_SONDA, SONDA_P1, SONDA_P2, SONDA_P3, SONDA_P4\n")
    f.write("# Condicion descartada: 100ms + 3 etapas\n")
    f.write("# Orden: estados de sonda -> ventanas -> etapas\n")
    f.write("\n")


def write_block_header(
    f,
    pcb: str,
    estado_sonda: str,
    ventana: str,
    etapas: int,
    bitstream_path: str,
):
    posicion_sonda = estado_to_posicion(estado_sonda)

    f.write("\n")
    f.write("============================================================\n")
    f.write(f"# TIMESTAMP: {datetime.now().isoformat(timespec='seconds')}\n")
    f.write(f"# PCB: {pcb}\n")
    f.write(f"# ESTADO_SONDA: {estado_sonda}\n")
    f.write(f"# POSICION_SONDA: {posicion_sonda}\n")
    f.write(f"# BITSTREAM: {os.path.basename(bitstream_path)}\n")
    f.write(f"# VENTANA: {ventana}\n")
    f.write(f"# ETAPAS_PRINCIPAL: {etapas}\n")
    f.write(f"# NUM_SAMPLES: {NUM_SAMPLES}\n")
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


def capture_block(
    ser,
    f,
    pcb: str,
    estado_sonda: str,
    ventana: str,
    etapas: int,
    bitstream_path: str,
):
    write_block_header(f, pcb, estado_sonda, ventana, etapas, bitstream_path)

    ser.reset_input_buffer()

    first = wait_for_first_valid_line(ser, max_wait_s=MAX_WAIT_FIRST_VALID_S)
    if first is None:
        raise RuntimeError(
            f"No llegaron datos válidos tras programar {os.path.basename(bitstream_path)}"
        )

    t_start = time.time()

    count = 0
    f.write(f"{count}\t{first[0]}\t{first[1]}\t{first[2]}\t{first[3]}\n")
    count += 1

    while count < NUM_SAMPLES:
        if time.time() - t_start > MAX_BLOCK_DURATION_S:
            raise TimeoutError(
                f"Timeout capturando bloque: PCB={pcb}, "
                f"SONDA={estado_sonda}, VENTANA={ventana}, ETAPAS={etapas}. "
                f"Muestras capturadas: {count}/{NUM_SAMPLES}"
            )

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
            elapsed = time.time() - t_start
            print(
                f"[{pcb} | {estado_sonda} | {ventana} - {etapas} etapas] "
                f"{count}/{NUM_SAMPLES} muestras "
                f"en {elapsed:.2f} s -> "
                f"{freqs[0]}, {freqs[1]}, {freqs[2]}, {freqs[3]}"
            )

    f.flush()

    elapsed = time.time() - t_start
    print(
        f"[{pcb} | {estado_sonda} | {ventana} - {etapas} etapas] "
        f"Captura finalizada: {count} muestras en {elapsed:.2f} s"
    )


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

        self._send_and_wait(
            'puts "__PY_VIVADO_READY__"',
            "__PY_VIVADO_READY__",
            timeout=120.0,
        )

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

                low = line.lower()

                if low.startswith("error:") or "no se ha encontrado ningún dispositivo" in low:
                    raise RuntimeError(
                        "Vivado devolvió un error:\n" + "\n".join(collected[-50:])
                    )

            except queue.Empty:
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


def prompt_pcb(pcb: str):
    print("\n" + "=" * 80)
    print(f"PREPARAR PCB: {pcb}")
    print("=" * 80)
    print(f"Coloca la PCB {pcb} en el sistema de medida.")
    print("Comprueba alimentación, conexión serie y cableado.")
    input("Cuando esté todo preparado, pulsa ENTER para continuar...")


def prompt_estado_sonda(pcb: str, estado_sonda: str, instruccion: str):
    print("\n" + "-" * 80)
    print(f"PCB: {pcb}")
    print(f"ESTADO DE MEDIDA: {estado_sonda}")
    print("-" * 80)
    print(instruccion)
    print("Se medirán todas las ventanas y etapas válidas para este estado.")
    input("Cuando la sonda esté colocada correctamente, pulsa ENTER para medir...")


def output_file_for_pcb(pcb: str):
    return os.path.join(OUTPUT_DIR, f"{pcb}_sonda.txt")


def medir_estado_completo(ser, vivado, f, pcb: str, estado_sonda: str):
    condiciones = get_valid_conditions()
    total = len(condiciones)

    for idx, (ventana, etapas) in enumerate(condiciones, start=1):
        bitstream_path = build_bitstream_path(ventana, etapas)

        print("\n" + "=" * 70)
        print(f"PCB         : {pcb}")
        print(f"Estado sonda: {estado_sonda}")
        print(f"Configuración {idx}/{total}")
        print(f"Ventana     : {ventana}")
        print(f"Etapas      : {etapas}")
        print(f"Bitstream   : {bitstream_path}")

        vivado.program_bitstream(bitstream_path)

        if POST_PROGRAM_DELAY_S > 0:
            print(f"Esperando {POST_PROGRAM_DELAY_S} s tras la programación...")
            time.sleep(POST_PROGRAM_DELAY_S)

        capture_block(
            ser=ser,
            f=f,
            pcb=pcb,
            estado_sonda=estado_sonda,
            ventana=ventana,
            etapas=etapas,
            bitstream_path=bitstream_path,
        )


def main():
    ensure_dir(OUTPUT_DIR)
    validate_paths()

    condiciones = get_valid_conditions()

    print("\nResumen de medida:")
    print(f"PCBs a medir: {len(PCBS_A_MEDIR)}")
    print(f"Estados de sonda por PCB: {len(ESTADOS_SONDA)}")
    print(f"Condiciones válidas por estado: {len(condiciones)}")
    print(f"Muestras por bloque: {NUM_SAMPLES}")
    print(f"Bloques por PCB: {len(ESTADOS_SONDA) * len(condiciones)}")
    print(f"Bloques totales: {len(PCBS_A_MEDIR) * len(ESTADOS_SONDA) * len(condiciones)}")
    print("\nCondiciones válidas:")
    for ventana, etapas in condiciones:
        print(f"  - {ventana}, {etapas} etapas")

    input("\nPulsa ENTER para iniciar la captura...")

    vivado = VivadoSession(VIVADO_BAT)

    try:
        vivado.start()

        with serial.Serial(PORT, BAUD, timeout=TIMEOUT_S) as ser:
            for pcb in PCBS_A_MEDIR:
                prompt_pcb(pcb)

                output_file = output_file_for_pcb(pcb)

                with open(output_file, "w", encoding="utf-8") as f:
                    write_file_header(f, pcb)

                    for estado_sonda, instruccion in ESTADOS_SONDA:
                        prompt_estado_sonda(pcb, estado_sonda, instruccion)
                        medir_estado_completo(ser, vivado, f, pcb, estado_sonda)

                print("\n" + "=" * 80)
                print(f"Medida finalizada para PCB: {pcb}")
                print(f"Datos guardados en: {output_file}")
                print("=" * 80)

    finally:
        vivado.close()

    print("\nProceso completado.")
    print(f"Datos guardados en la carpeta: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()