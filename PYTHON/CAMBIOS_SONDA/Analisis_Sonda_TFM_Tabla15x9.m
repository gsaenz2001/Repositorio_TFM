function Analisis_Sonda_TFM_Tabla15x9()
% ANALISIS DE CAMBIOS CON SONDA - TABLAS 15x9 POR PCB
%
% Salida principal:
%   Una tabla por PCB con 15 condiciones x 9 columnas:
%
%   Condicion
%   P1_dir_pct   P1_adj_pct
%   P2_dir_pct   P2_adj_pct
%   P3_dir_pct   P3_adj_pct
%   P4_dir_pct   P4_adj_pct
%
% Donde:
%   Pk_dir_pct = |DeltaModa_pct(SONDA_Pk -> Pk)|
%   Pk_adj_pct = media de |DeltaModa_pct(SONDA_Pk -> pistas adyacentes)|
%
% Este script calcula la moda usando la parte estable final de cada bloque
% para evitar que los transitorios iniciales afecten al resultado.

clc;
close all;
format compact;
format short g;

%% =========================================================
%  CONFIGURACION
%% =========================================================

carpeta = "D:\TFM\PYTHON\CAMBIOS_SONDA";

% ==========================================================
% CAMBIA SOLO ESTA ZONA PARA ANALIZAR TODAS O UNA PCB
% ==========================================================

% ---- TODAS ----
nombreAnalisis = "TODAS";
pcbsAnalisis = [
    "M1_2L_4"
    "M2_2L_4_06"
    "M2_2L_4_10"
    "M2_2L_4_16"
    "M3_2L_5"
    "M4_2L_5"
    "M5_2L_4"
];

% ---- M1 ----
% nombreAnalisis = "M1_2L_4";
% pcbsAnalisis = ["M1_2L_4"];

% ---- M2 ----
% nombreAnalisis = "M2_2L";
% pcbsAnalisis = [
%     "M2_2L_4_06"
%     "M2_2L_4_10"
%     "M2_2L_4_16"
% ];

% ---- M3 ----
% nombreAnalisis = "M3_2L_5";
% pcbsAnalisis = ["M3_2L_5"];

% ---- M4 ----
% nombreAnalisis = "M4_2L_5";
% pcbsAnalisis = ["M4_2L_5"];

% ---- M5 ----
% nombreAnalisis = "M5_2L_4";
% pcbsAnalisis = ["M5_2L_4"];


% ----------------------------------------------------------
% Orden de condiciones
% ----------------------------------------------------------

ventanasOrden = ["100ms", "10ms", "1ms", "100us"];
etapasOrden   = [3, 5, 51, 101];

% Condicion descartada tras el estudio de estabilidad.
condicionesDescartadas = [
    "100ms", "3"
];

numPistas = 4;


% ----------------------------------------------------------
% Preprocesado
% ----------------------------------------------------------

% Numero minimo de muestras iniciales a descartar.
% Se mantiene por seguridad, pero la seleccion principal se hace usando
% la parte final estable del bloque.
numMuestrasInicialesDescartar = 10;

% Usar solo la parte final del bloque para calcular la moda.
% Esto evita que los transitorios iniciales dominen el calculo.
usarSoloParteFinalBloque = true;

% Numero de muestras finales empleadas para calcular la moda.
% Con bloques de 500 muestras, usar las ultimas 300 elimina gran parte
% del transitorio inicial observado en las medidas con sonda.
numMuestrasFinalesUsar = 300;

% Redondeo por resolucion de ventana antes de la moda:
%   100ms -> 10 Hz
%   10ms  -> 100 Hz
%   1ms   -> 1000 Hz
%   100us -> 10000 Hz

% Filtro MAD opcional. Por defecto desactivado.
usarFiltroRobustoMAD = false;
Kmad = 8;

% La tabla usa el modulo del cambio, porque se quiere cuantificar
% cuanto cambia la sonda. Si quieres ver el signo, ponlo a false.
usarValorAbsoluto = true;


%% =========================================================
%  1. LECTURA
%% =========================================================

fprintf("\n============================================================\n");
fprintf("ANALISIS SONDA - TABLAS 15x9 POR PCB\n");
fprintf("Analisis: %s\n", char(nombreAnalisis));
fprintf("Carpeta: %s\n", char(carpeta));
fprintf("Valor mostrado: ");
if usarValorAbsoluto
    fprintf("|DeltaModa_pct|\n");
else
    fprintf("DeltaModa_pct con signo\n");
end
fprintf("Muestras iniciales descartadas minimo: %d\n", numMuestrasInicialesDescartar);
if usarSoloParteFinalBloque
    fprintf("Usando solo las ultimas %d muestras validas de cada bloque\n", numMuestrasFinalesUsar);
else
    fprintf("Usando todas las muestras tras descartar el inicio\n");
end
fprintf("============================================================\n");

Datos = table();

for i = 1:numel(pcbsAnalisis)

    pcb = pcbsAnalisis(i);
    archivo = buscarArchivoSonda(carpeta, pcb);

    if archivo == ""
        warning("No se ha encontrado archivo de sonda para %s", char(pcb));
        continue;
    end

    fprintf("Leyendo: %s\n", char(archivo));

    T = leerArchivoSonda(archivo);

    if isempty(T)
        warning("Archivo sin datos validos: %s", char(archivo));
        continue;
    end

    Datos = [Datos; T]; %#ok<AGROW>

end

if isempty(Datos)
    error("No se han leido datos. Revisa carpeta y nombres de archivos.");
end

Datos = filtrarCondicionesDescartadas(Datos, condicionesDescartadas);
Datos.ConfigID = calcularConfigID(Datos.Ventana, Datos.Etapas, ventanasOrden, etapasOrden);
Datos.Condicion = Datos.Ventana + "-" + string(Datos.Etapas) + "e";

Datos = sortrows(Datos, {'PCB','EstadoSonda','ConfigID','Idx'});


%% =========================================================
%  2. MODA POR BLOQUE
%% =========================================================

StatsModa = calcularStatsModaPorBloque( ...
    Datos, ...
    numPistas, ...
    numMuestrasInicialesDescartar, ...
    usarSoloParteFinalBloque, ...
    numMuestrasFinalesUsar, ...
    usarFiltroRobustoMAD, ...
    Kmad);


%% =========================================================
%  3. CAMBIO CONTRA SIN_SONDA
%% =========================================================

Cambios = calcularCambiosModa(StatsModa);


%% =========================================================
%  4. TABLAS 15x9 POR PCB
%% =========================================================

Tablas15x9 = struct();

pcbs = unique(Cambios.PCB, 'stable');

fprintf("\n============================================================\n");
fprintf("TABLAS 15x9 POR PCB\n");
fprintf("Columnas:\n");
fprintf("  Pk_dir_pct = cambio de SONDA_Pk sobre Pk\n");
fprintf("  Pk_adj_pct = media del cambio de SONDA_Pk sobre pistas adyacentes\n");
fprintf("============================================================\n");

for i = 1:numel(pcbs)

    pcb = pcbs(i);

    Tpcb = construirTabla15x9( ...
        Cambios, ...
        pcb, ...
        ventanasOrden, ...
        etapasOrden, ...
        usarValorAbsoluto);

    fprintf("\n------------------------------------------------------------\n");
    fprintf("PCB: %s\n", char(pcb));
    fprintf("------------------------------------------------------------\n");
    disp(Tpcb);

    nombreCampo = matlab.lang.makeValidName(char(pcb));
    Tablas15x9.(nombreCampo) = Tpcb;

    nombreVar = matlab.lang.makeValidName("Tabla_" + pcb);
    assignin('base', nombreVar, Tpcb);

end

assignin('base', 'Tablas15x9', Tablas15x9);
assignin('base', 'StatsModa', StatsModa);
assignin('base', 'Cambios', Cambios);
assignin('base', 'DatosSonda', Datos);

fprintf("\n============================================================\n");
fprintf("PROCESO COMPLETADO\n");
fprintf("No se ha guardado ningun CSV ni ninguna imagen.\n");
fprintf("Variables en workspace: DatosSonda, StatsModa, Cambios, Tablas15x9\n");
fprintf("Tambien hay una variable Tabla_NOMBREPCB por cada PCB.\n");
fprintf("============================================================\n");

end


%% ========================================================================
%  CONSTRUCCION DE LA TABLA 15x9
%% ========================================================================

function Tpcb = construirTabla15x9(Cambios, pcb, ventanasOrden, etapasOrden, usarAbs)

Condicion = strings(0,1);

P1_dir_pct = zeros(0,1);
P1_adj_pct = zeros(0,1);

P2_dir_pct = zeros(0,1);
P2_adj_pct = zeros(0,1);

P3_dir_pct = zeros(0,1);
P3_adj_pct = zeros(0,1);

P4_dir_pct = zeros(0,1);
P4_adj_pct = zeros(0,1);

for v = 1:numel(ventanasOrden)
    for e = 1:numel(etapasOrden)

        ventana = ventanasOrden(v);
        etapas = etapasOrden(e);

        if ventana == "100ms" && etapas == 3
            continue;
        end

        filaCond = ventana + "-" + string(etapas) + "e";

        valoresDir = NaN(1,4);
        valoresAdj = NaN(1,4);

        for p = 1:4

            % Cambio directo: SONDA_Pp -> Pp
            idxDir = ...
                Cambios.PCB == pcb & ...
                Cambios.Ventana == ventana & ...
                Cambios.Etapas == etapas & ...
                Cambios.SondaPista == p & ...
                Cambios.PistaMedida == p;

            if any(idxDir)
                if usarAbs
                    valoresDir(p) = Cambios.DeltaModaAbs_pct(find(idxDir,1));
                else
                    valoresDir(p) = Cambios.DeltaModa_pct(find(idxDir,1));
                end
            end

            % Cambios adyacentes: SONDA_Pp -> pistas vecinas
            idxAdj = ...
                Cambios.PCB == pcb & ...
                Cambios.Ventana == ventana & ...
                Cambios.Etapas == etapas & ...
                Cambios.SondaPista == p & ...
                abs(Cambios.PistaMedida - p) == 1;

            if any(idxAdj)
                if usarAbs
                    valoresAdj(p) = mean(Cambios.DeltaModaAbs_pct(idxAdj), 'omitnan');
                else
                    valoresAdj(p) = mean(Cambios.DeltaModa_pct(idxAdj), 'omitnan');
                end
            end

        end

        Condicion(end+1,1) = filaCond; %#ok<AGROW>

        P1_dir_pct(end+1,1) = valoresDir(1); %#ok<AGROW>
        P1_adj_pct(end+1,1) = valoresAdj(1); %#ok<AGROW>

        P2_dir_pct(end+1,1) = valoresDir(2); %#ok<AGROW>
        P2_adj_pct(end+1,1) = valoresAdj(2); %#ok<AGROW>

        P3_dir_pct(end+1,1) = valoresDir(3); %#ok<AGROW>
        P3_adj_pct(end+1,1) = valoresAdj(3); %#ok<AGROW>

        P4_dir_pct(end+1,1) = valoresDir(4); %#ok<AGROW>
        P4_adj_pct(end+1,1) = valoresAdj(4); %#ok<AGROW>

    end
end

Tpcb = table( ...
    Condicion, ...
    P1_dir_pct, ...
    P1_adj_pct, ...
    P2_dir_pct, ...
    P2_adj_pct, ...
    P3_dir_pct, ...
    P3_adj_pct, ...
    P4_dir_pct, ...
    P4_adj_pct);

end


%% ========================================================================
%  LECTURA DE FICHEROS
%% ========================================================================

function archivo = buscarArchivoSonda(carpeta, pcb)

archivo = "";

candidatos = [
    fullfile(carpeta, pcb + "_sonda.txt")
    fullfile(carpeta, pcb + "_sonda")
    fullfile(carpeta, pcb + ".txt")
    fullfile(carpeta, pcb)
];

for i = 1:numel(candidatos)
    if isfile(candidatos(i))
        archivo = candidatos(i);
        return;
    end
end

d = dir(fullfile(carpeta, "*" + pcb + "*sonda*.txt"));
if ~isempty(d)
    archivo = fullfile(d(1).folder, d(1).name);
end

end


function T = leerArchivoSonda(archivo)

texto = fileread(archivo);
lineas = splitlines(string(texto));

PCB = strings(0,1);
EstadoSonda = strings(0,1);
Ventana = strings(0,1);
Etapas = zeros(0,1);
Idx = zeros(0,1);
F = zeros(0,4);

metaPCB = "";
metaEstado = "";
metaVentana = "";
metaEtapas = NaN;
leyendoDatos = false;

for i = 1:numel(lineas)

    s = strtrim(lineas(i));

    if strlength(s) == 0
        continue;
    end

    if startsWith(s, "# PCB:")
        metaPCB = strtrim(extractAfter(s, "# PCB:"));
        continue;
    end

    if startsWith(s, "# ESTADO_SONDA:")
        metaEstado = strtrim(extractAfter(s, "# ESTADO_SONDA:"));
        continue;
    end

    if startsWith(s, "# VENTANA:")
        metaVentana = strtrim(extractAfter(s, "# VENTANA:"));
        continue;
    end

    if startsWith(s, "# ETAPAS_PRINCIPAL:")
        metaEtapas = str2double(strtrim(extractAfter(s, "# ETAPAS_PRINCIPAL:")));
        continue;
    end

    if startsWith(s, "idx")
        leyendoDatos = true;
        continue;
    end

    if startsWith(s, "====")
        leyendoDatos = false;
        continue;
    end

    if leyendoDatos

        nums = regexp(s, "[-+]?\d+\.?\d*", "match");

        if numel(nums) < 5
            continue;
        end

        idx = str2double(nums{1});
        freqs = str2double(nums(2:5));

        if any(isnan(freqs))
            continue;
        end

        PCB(end+1,1) = metaPCB; %#ok<AGROW>
        EstadoSonda(end+1,1) = metaEstado; %#ok<AGROW>
        Ventana(end+1,1) = metaVentana; %#ok<AGROW>
        Etapas(end+1,1) = metaEtapas; %#ok<AGROW>
        Idx(end+1,1) = idx; %#ok<AGROW>
        F(end+1,:) = freqs; %#ok<AGROW>

    end

end

T = table( ...
    PCB, ...
    EstadoSonda, ...
    Ventana, ...
    Etapas, ...
    Idx, ...
    F(:,1), ...
    F(:,2), ...
    F(:,3), ...
    F(:,4), ...
    'VariableNames', { ...
        'PCB', ...
        'EstadoSonda', ...
        'Ventana', ...
        'Etapas', ...
        'Idx', ...
        'Freq1', ...
        'Freq2', ...
        'Freq3', ...
        'Freq4'});

end


function Datos = filtrarCondicionesDescartadas(Datos, condicionesDescartadas)

if isempty(Datos) || isempty(condicionesDescartadas)
    return;
end

mantener = true(height(Datos),1);

for i = 1:size(condicionesDescartadas,1)

    ventana = condicionesDescartadas(i,1);
    etapas = str2double(condicionesDescartadas(i,2));

    idx = Datos.Ventana == ventana & Datos.Etapas == etapas;
    mantener(idx) = false;

end

Datos = Datos(mantener,:);

end


%% ========================================================================
%  CONFIGURACIONES Y RESOLUCIONES
%% ========================================================================

function id = calcularConfigID(ventana, etapas, ventanasOrden, etapasOrden)

id = NaN(numel(ventana),1);
contador = 0;

for v = 1:numel(ventanasOrden)
    for e = 1:numel(etapasOrden)

        if ventanasOrden(v) == "100ms" && etapasOrden(e) == 3
            continue;
        end

        contador = contador + 1;
        idx = ventana == ventanasOrden(v) & etapas == etapasOrden(e);
        id(idx) = contador;

    end
end

end


function resolucion = resolucionVentanaHz(ventana)

switch string(ventana)
    case "100ms"
        resolucion = 10;
    case "10ms"
        resolucion = 100;
    case "1ms"
        resolucion = 1000;
    case "100us"
        resolucion = 10000;
    otherwise
        error("Ventana no reconocida: %s", char(ventana));
end

end


%% ========================================================================
%  MODA POR BLOQUE
%% ========================================================================

function StatsModa = calcularStatsModaPorBloque( ...
    Datos, ...
    numPistas, ...
    nDescartarInicio, ...
    usarSoloParteFinalBloque, ...
    numMuestrasFinalesUsar, ...
    usarFiltroMAD, ...
    Kmad)

comb = unique(Datos(:, {'PCB','EstadoSonda','Ventana','Etapas','ConfigID','Condicion'}), 'rows', 'stable');
StatsModa = table();

for i = 1:height(comb)

    idxBloque = ...
        Datos.PCB == comb.PCB(i) & ...
        Datos.EstadoSonda == comb.EstadoSonda(i) & ...
        Datos.Ventana == comb.Ventana(i) & ...
        Datos.Etapas == comb.Etapas(i);

    Tbloque = Datos(idxBloque,:);

    resolucion = resolucionVentanaHz(comb.Ventana(i));

    for p = 1:numPistas

        nombreFreq = "Freq" + string(p);
        x = Tbloque.(char(nombreFreq));

        [ ...
            modaHz, ...
            medianaHz, ...
            nOriginales, ...
            nDescartadasInicio, ...
            nAntesFiltroMAD, ...
            nValidas, ...
            nEmpate, ...
            cuentaModa ...
        ] = calcularModaBloque( ...
            x, ...
            resolucion, ...
            nDescartarInicio, ...
            usarSoloParteFinalBloque, ...
            numMuestrasFinalesUsar, ...
            usarFiltroMAD, ...
            Kmad);

        fila = table( ...
            comb.PCB(i), ...
            comb.EstadoSonda(i), ...
            comb.Ventana(i), ...
            comb.Etapas(i), ...
            comb.ConfigID(i), ...
            comb.Condicion(i), ...
            resolucion, ...
            p, ...
            "P" + string(p), ...
            modaHz, ...
            medianaHz, ...
            nOriginales, ...
            nDescartadasInicio, ...
            nAntesFiltroMAD, ...
            nValidas, ...
            nEmpate, ...
            cuentaModa, ...
            'VariableNames', { ...
                'PCB', ...
                'EstadoSonda', ...
                'Ventana', ...
                'Etapas', ...
                'ConfigID', ...
                'Condicion', ...
                'Resolucion_Hz', ...
                'Pista', ...
                'NombrePista', ...
                'Moda_Hz', ...
                'Mediana_Hz', ...
                'NumMuestrasOriginales', ...
                'NumDescartadasInicio', ...
                'NumMuestrasAntesFiltroMAD', ...
                'NumMuestrasValidas', ...
                'NumModasEmpatadas', ...
                'CuentaModa'});

        StatsModa = [StatsModa; fila]; %#ok<AGROW>

    end

end

StatsModa = sortrows(StatsModa, {'PCB','EstadoSonda','ConfigID','Pista'});

end


function [ ...
    modaHz, ...
    medianaHz, ...
    nOriginales, ...
    nDescartadasInicio, ...
    nAntesFiltroMAD, ...
    nValidas, ...
    nEmpate, ...
    cuentaModa ...
] = calcularModaBloque( ...
    x, ...
    resolucion, ...
    nDescartarInicio, ...
    usarSoloParteFinalBloque, ...
    numMuestrasFinalesUsar, ...
    usarFiltroMAD, ...
    Kmad)

x = x(:);
x = x(~isnan(x));
x = x(x > 0);

nOriginales = numel(x);

modaHz = NaN;
medianaHz = NaN;
nDescartadasInicio = 0;
nAntesFiltroMAD = 0;
nValidas = 0;
nEmpate = 0;
cuentaModa = 0;

if isempty(x)
    return;
end

% 1. Descarte minimo de muestras iniciales
nDescartadasInicio = min(nDescartarInicio, numel(x));

if numel(x) > nDescartadasInicio
    x = x(nDescartadasInicio+1:end);
else
    x = [];
end

if isempty(x)
    return;
end

% 2. Seleccion de la parte final estable del bloque
if usarSoloParteFinalBloque && numel(x) > numMuestrasFinalesUsar
    x = x(end-numMuestrasFinalesUsar+1:end);
end

if isempty(x)
    return;
end

% 3. Filtro MAD opcional
nAntesFiltroMAD = numel(x);

if usarFiltroMAD && numel(x) > 20
    med0 = median(x);
    mad0 = median(abs(x - med0));

    if mad0 > 0
        idx = abs(x - med0) <= Kmad * mad0;
        x = x(idx);
    end
end

if isempty(x)
    return;
end

% 4. Redondeo segun resolucion de medida
xRed = round(x ./ resolucion) .* resolucion;

medianaHz = median(xRed);
nValidas = numel(xRed);

% 5. Moda. Si hay empate, se elige la candidata mas proxima a la mediana.
[u, ~, ic] = unique(xRed);
cuentas = accumarray(ic, 1);

cuentaModa = max(cuentas);
candidatas = u(cuentas == cuentaModa);
nEmpate = numel(candidatas);

[~, idxMejor] = min(abs(candidatas - medianaHz));
modaHz = candidatas(idxMejor);

end


%% ========================================================================
%  CAMBIOS DE MODA
%% ========================================================================

function Cambios = calcularCambiosModa(StatsModa)

Stats0 = StatsModa(StatsModa.EstadoSonda == "SIN_SONDA", :);
StatsS = StatsModa(StatsModa.EstadoSonda ~= "SIN_SONDA", :);

Cambios = table();

for i = 1:height(StatsS)

    s = StatsS(i,:);

    idx0 = ...
        Stats0.PCB == s.PCB & ...
        Stats0.Ventana == s.Ventana & ...
        Stats0.Etapas == s.Etapas & ...
        Stats0.Pista == s.Pista;

    if ~any(idx0)
        continue;
    end

    b = Stats0(find(idx0,1), :);

    moda0 = b.Moda_Hz;
    modaS = s.Moda_Hz;

    if isnan(moda0) || isnan(modaS) || moda0 <= 0
        continue;
    end

    deltaHz = modaS - moda0;
    deltaPct = 100 * deltaHz / moda0;

    sondaPista = extraerPistaSonda(s.EstadoSonda);
    pistaMedida = s.Pista;

    distancia = abs(pistaMedida - sondaPista);

    if distancia == 0
        tipoEfecto = "DIRECTA";
    elseif distancia == 1
        tipoEfecto = "ADYACENTE";
    else
        tipoEfecto = "NO_ADYACENTE";
    end

    fila = table( ...
        s.PCB, ...
        s.EstadoSonda, ...
        sondaPista, ...
        s.Ventana, ...
        s.Etapas, ...
        s.ConfigID, ...
        s.Condicion, ...
        pistaMedida, ...
        "P" + string(pistaMedida), ...
        distancia, ...
        tipoEfecto, ...
        moda0, ...
        modaS, ...
        deltaHz, ...
        abs(deltaHz), ...
        deltaPct, ...
        abs(deltaPct), ...
        b.NumMuestrasValidas, ...
        s.NumMuestrasValidas, ...
        'VariableNames', { ...
            'PCB', ...
            'EstadoSonda', ...
            'SondaPista', ...
            'Ventana', ...
            'Etapas', ...
            'ConfigID', ...
            'Condicion', ...
            'PistaMedida', ...
            'NombrePistaMedida', ...
            'Distancia', ...
            'TipoEfecto', ...
            'ModaSinSonda_Hz', ...
            'ModaConSonda_Hz', ...
            'DeltaModa_Hz', ...
            'DeltaModaAbs_Hz', ...
            'DeltaModa_pct', ...
            'DeltaModaAbs_pct', ...
            'NumMuestrasSinSonda', ...
            'NumMuestrasConSonda'});

    Cambios = [Cambios; fila]; %#ok<AGROW>

end

Cambios = sortrows(Cambios, {'PCB','ConfigID','SondaPista','PistaMedida'});

end


function p = extraerPistaSonda(estado)

tokens = regexp(char(estado), "SONDA_P(\d+)", "tokens");

if isempty(tokens)
    p = NaN;
else
    p = str2double(tokens{1}{1});
end

end