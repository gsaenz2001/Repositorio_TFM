function Analisis_Compromiso_Estabilidad_Deteccion_v5()
% ANALISIS FINAL: COMPROMISO ENTRE ESTABILIDAD Y DETECCION CON SONDA
%
% Este script:
%   - Lee directamente los ficheros *_sonda.txt.
%   - Calcula la estabilidad sin sonda a partir de los bloques SIN_SONDA.
%   - Calcula la deteccion de cambios con sonda a partir del cambio directo.
%   - Descarta las primeras muestras de cada bloque.
%   - Usa la parte final estable del bloque para calcular la moda.
%   - Normaliza estabilidad y deteccion entre 0 y 100.
%   - Calcula un indice de compromiso ponderado.
%   - Muestra la tabla final, el Top 10 y la mejor configuracion global.
%   - Genera una grafica interactiva en la que se pueden ocultar PCBs
%     pinchando sobre su nombre en la leyenda.
%
% Grafica:
%   Eje X = 15 condiciones
%   Eje Y = indice de compromiso estabilidad-deteccion [0-100]
%   Color = PCB
%
% No guarda CSV.
% No guarda imagenes.

clc;
close all;
format compact;
format short g;

%% =========================================================
%  CONFIGURACION
%% =========================================================

carpeta = "D:\TFM\PYTHON\CAMBIOS_SONDA";

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

ventanasOrden = ["100ms", "10ms", "1ms", "100us"];
etapasOrden   = [3, 5, 51, 101];

% Condicion descartada por estabilidad.
condicionesDescartadas = [
    "100ms", "3"
];

% Primeras muestras descartadas de cada bloque.
numMuestrasInicialesDescartar = 10;

% Uso de la parte final estable del bloque.
usarSoloParteFinalBloque = true;
numMuestrasFinalesUsar = 300;

% Filtro robusto opcional.
usarFiltroRobustoMAD = false;
Kmad = 8;

% Tipo de indice final:
%   "geometrico": media geometrica 50/50
%   "ponderado":  media geometrica ponderada
%   "media":      media aritmetica 50/50
tipoIndice = "ponderado";

% Pesos del indice ponderado.
% Si quieres 60/40:
%   pesoEstabilidad = 0.4;
%   pesoDeteccion   = 0.6;
%
% Si quieres dar aun mas peso a la sonda:
%   pesoEstabilidad = 0.2;
%   pesoDeteccion   = 0.8;
pesoEstabilidad = 0.4;
pesoDeteccion   = 0.6;

% Separacion horizontal entre PCBs dentro de una misma condicion.
usarDesplazamientoHorizontal = false;
amplitudDesplazamiento = 0;

% Numero de mejores configuraciones a mostrar.
numTopConfiguraciones = 10;


%% =========================================================
%  1. LEER DATOS
%% =========================================================

fprintf("\n============================================================\n");
fprintf("ANALISIS FINAL ESTABILIDAD + DETECCION CON SONDA\n");
fprintf("Analisis: %s\n", char(nombreAnalisis));
fprintf("Carpeta: %s\n", char(carpeta));
fprintf("Indice: %s\n", char(tipoIndice));
fprintf("Peso estabilidad: %.2f\n", pesoEstabilidad);
fprintf("Peso deteccion: %.2f\n", pesoDeteccion);
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
    error("No se han leido datos. Revisa la carpeta y los nombres de los archivos.");
end

Datos = filtrarCondicionesDescartadas(Datos, condicionesDescartadas);
Datos.ConfigID = calcularConfigID(Datos.Ventana, Datos.Etapas, ventanasOrden, etapasOrden);
Datos.ConfigLabel = Datos.Ventana + "-" + string(Datos.Etapas) + "e";

Datos = sortrows(Datos, {'PCB','EstadoSonda','ConfigID','Idx'});

ConfigInfo = crearTablaConfiguraciones(ventanasOrden, etapasOrden);

fprintf("\nConfiguraciones analizadas:\n");
disp(ConfigInfo);


%% =========================================================
%  2. TABLA FINAL
%% =========================================================

ResumenFinal = calcularResumenFinal( ...
    Datos, ...
    ventanasOrden, ...
    etapasOrden, ...
    numMuestrasInicialesDescartar, ...
    usarSoloParteFinalBloque, ...
    numMuestrasFinalesUsar, ...
    usarFiltroRobustoMAD, ...
    Kmad);

ResumenFinal = normalizarYCalcularIndice( ...
    ResumenFinal, ...
    tipoIndice, ...
    pesoEstabilidad, ...
    pesoDeteccion);

RankingCompromiso = sortrows( ...
    ResumenFinal, ...
    {'IndiceCompromiso','DeteccionScore','EstabilidadScore'}, ...
    {'descend','descend','descend'});

RankingCompromiso.Rank = (1:height(RankingCompromiso)).';

MejorPorPCB = seleccionarMejorPorPCB(RankingCompromiso);

numTop = min(numTopConfiguraciones, height(RankingCompromiso));
Top10Compromiso = RankingCompromiso(1:numTop, :);


%% =========================================================
%  3. MOSTRAR TABLAS
%% =========================================================

columnasMostrar = { ...
    'Rank', ...
    'PCB', ...
    'ConfigID', ...
    'ConfigLabel', ...
    'DispersionSinSonda_pct', ...
    'CambioDirectoMedioAbs_pct', ...
    'CambioAdyacenteMedioAbs_pct', ...
    'AdjSobreDirecto_pct', ...
    'EstabilidadScore', ...
    'DeteccionScore', ...
    'IndiceCompromiso'};

fprintf("\n============================================================\n");
fprintf("TABLA FINAL: ESTABILIDAD, DETECCION E INDICE DE COMPROMISO\n");
fprintf("============================================================\n");
disp(RankingCompromiso(:, columnasMostrar));

fprintf("\n============================================================\n");
fprintf("TOP %d CONFIGURACIONES SEGUN INDICE DE COMPROMISO\n", numTop);
fprintf("============================================================\n");
disp(Top10Compromiso(:, columnasMostrar));

fprintf("\n============================================================\n");
fprintf("MEJOR CONFIGURACION POR PCB\n");
fprintf("============================================================\n");
disp(MejorPorPCB(:, columnasMostrar));

fprintf("\n============================================================\n");
fprintf("MEJOR CONFIGURACION GLOBAL\n");
fprintf("============================================================\n");
disp(RankingCompromiso(1, columnasMostrar));


%% =========================================================
%  4. GRAFICA GENERAL
%% =========================================================

graficarPuntosGeneral( ...
    ResumenFinal, ...
    MejorPorPCB, ...
    ConfigInfo, ...
    usarDesplazamientoHorizontal, ...
    amplitudDesplazamiento);


%% =========================================================
%  5. EXPORTAR AL WORKSPACE
%% =========================================================

assignin('base', 'DatosSonda', Datos);
assignin('base', 'ResumenCompromiso', ResumenFinal);
assignin('base', 'RankingCompromiso', RankingCompromiso);
assignin('base', 'Top10Compromiso', Top10Compromiso);
assignin('base', 'MejorPorPCB_Compromiso', MejorPorPCB);
assignin('base', 'ConfigInfoCompromiso', ConfigInfo);

fprintf("\n============================================================\n");
fprintf("PROCESO COMPLETADO\n");
fprintf("No se ha guardado ningun CSV ni ninguna imagen.\n");
fprintf("Variables en workspace:\n");
fprintf("  DatosSonda\n");
fprintf("  ResumenCompromiso\n");
fprintf("  RankingCompromiso\n");
fprintf("  Top10Compromiso\n");
fprintf("  MejorPorPCB_Compromiso\n");
fprintf("  ConfigInfoCompromiso\n");
fprintf("============================================================\n");

end


%% ========================================================================
%  CALCULO PRINCIPAL
%% ========================================================================

function Resumen = calcularResumenFinal( ...
    Datos, ...
    ventanasOrden, ...
    etapasOrden, ...
    nDescartar, ...
    usarSoloParteFinal, ...
    nFinales, ...
    usarFiltroMAD, ...
    Kmad)

pcbs = unique(Datos.PCB, 'stable');

PCB = strings(0,1);
Ventana = strings(0,1);
Etapas = zeros(0,1);
ConfigID = zeros(0,1);
ConfigLabel = strings(0,1);

DispersionSinSonda_pct = zeros(0,1);
CambioDirectoMedioAbs_pct = zeros(0,1);
CambioAdyacenteMedioAbs_pct = zeros(0,1);
AdjSobreDirecto_pct = zeros(0,1);

for ip = 1:numel(pcbs)

    pcb = pcbs(ip);

    for v = 1:numel(ventanasOrden)
        for e = 1:numel(etapasOrden)

            ventana = ventanasOrden(v);
            etapas = etapasOrden(e);

            if ventana == "100ms" && etapas == 3
                continue;
            end

            Tcond = Datos( ...
                Datos.PCB == pcb & ...
                Datos.Ventana == ventana & ...
                Datos.Etapas == etapas, :);

            if isempty(Tcond)
                continue;
            end

            resolucion = resolucionVentanaHz(ventana);

            % ----------------------------------------------------------
            % 1) Estabilidad sin sonda.
            % ----------------------------------------------------------

            dispPistas = NaN(1,4);
            modasSinSonda = NaN(1,4);

            Tbase = Tcond(Tcond.EstadoSonda == "SIN_SONDA", :);

            for pista = 1:4

                nombreFreq = "Freq" + string(pista);
                x = Tbase.(char(nombreFreq));

                [modaBase, xRed] = calcularModaRobusta( ...
                    x, ...
                    resolucion, ...
                    nDescartar, ...
                    usarSoloParteFinal, ...
                    nFinales, ...
                    usarFiltroMAD, ...
                    Kmad);

                modasSinSonda(pista) = modaBase;

                if ~isempty(xRed) && ~isnan(modaBase) && modaBase > 0
                    dispPistas(pista) = mean(abs(xRed - modaBase), 'omitnan') / modaBase * 100;
                end

            end

            dispersionCond = mean(dispPistas, 'omitnan');

            % ----------------------------------------------------------
            % 2) Deteccion con sonda.
            % ----------------------------------------------------------

            cambiosDirectos = NaN(1,4);
            cambiosAdyPorSonda = NaN(1,4);

            for k = 1:4

                estado = "SONDA_P" + string(k);
                Tsonda = Tcond(Tcond.EstadoSonda == estado, :);

                if isempty(Tsonda)
                    continue;
                end

                % Directo: SONDA_Pk -> Pk.
                nombreFreqDir = "Freq" + string(k);
                xDir = Tsonda.(char(nombreFreqDir));

                [modaSondaDir, ~] = calcularModaRobusta( ...
                    xDir, ...
                    resolucion, ...
                    nDescartar, ...
                    usarSoloParteFinal, ...
                    nFinales, ...
                    usarFiltroMAD, ...
                    Kmad);

                modaBaseDir = modasSinSonda(k);

                if ~isnan(modaBaseDir) && modaBaseDir > 0 && ~isnan(modaSondaDir)
                    cambiosDirectos(k) = abs(100 * (modaSondaDir - modaBaseDir) / modaBaseDir);
                end

                % Adyacentes: SONDA_Pk -> pistas vecinas.
                adyacentes = encontrarAdyacentes(k);
                cambiosAdy = NaN(1,numel(adyacentes));

                for a = 1:numel(adyacentes)

                    pistaAdj = adyacentes(a);
                    nombreFreqAdj = "Freq" + string(pistaAdj);
                    xAdj = Tsonda.(char(nombreFreqAdj));

                    [modaSondaAdj, ~] = calcularModaRobusta( ...
                        xAdj, ...
                        resolucion, ...
                        nDescartar, ...
                        usarSoloParteFinal, ...
                        nFinales, ...
                        usarFiltroMAD, ...
                        Kmad);

                    modaBaseAdj = modasSinSonda(pistaAdj);

                    if ~isnan(modaBaseAdj) && modaBaseAdj > 0 && ~isnan(modaSondaAdj)
                        cambiosAdy(a) = abs(100 * (modaSondaAdj - modaBaseAdj) / modaBaseAdj);
                    end

                end

                cambiosAdyPorSonda(k) = mean(cambiosAdy, 'omitnan');

            end

            cambioDirecto = mean(cambiosDirectos, 'omitnan');
            cambioAdy = mean(cambiosAdyPorSonda, 'omitnan');

            PCB(end+1,1) = pcb; %#ok<AGROW>
            Ventana(end+1,1) = ventana; %#ok<AGROW>
            Etapas(end+1,1) = etapas; %#ok<AGROW>
            ConfigID(end+1,1) = calcularConfigID(ventana, etapas, ventanasOrden, etapasOrden); %#ok<AGROW>
            ConfigLabel(end+1,1) = ventana + "-" + string(etapas) + "e"; %#ok<AGROW>

            DispersionSinSonda_pct(end+1,1) = dispersionCond; %#ok<AGROW>
            CambioDirectoMedioAbs_pct(end+1,1) = cambioDirecto; %#ok<AGROW>
            CambioAdyacenteMedioAbs_pct(end+1,1) = cambioAdy; %#ok<AGROW>
            AdjSobreDirecto_pct(end+1,1) = 100 * cambioAdy / max(cambioDirecto, eps); %#ok<AGROW>

        end
    end
end

Resumen = table( ...
    PCB, ...
    Ventana, ...
    Etapas, ...
    ConfigID, ...
    ConfigLabel, ...
    DispersionSinSonda_pct, ...
    CambioDirectoMedioAbs_pct, ...
    CambioAdyacenteMedioAbs_pct, ...
    AdjSobreDirecto_pct);

Resumen = sortrows(Resumen, {'PCB','ConfigID'});

end


function Resumen = normalizarYCalcularIndice( ...
    Resumen, ...
    tipoIndice, ...
    pesoEstabilidad, ...
    pesoDeteccion)

D = Resumen.DispersionSinSonda_pct;
C = Resumen.CambioDirectoMedioAbs_pct;

idxD = ~isnan(D) & D >= 0;
idxC = ~isnan(C) & C >= 0;

Dpositivos = D(idxD & D > 0);

if isempty(Dpositivos)
    Dmin = 1;
else
    Dmin = min(Dpositivos);
end

Cvalidos = C(idxC);

if isempty(Cvalidos)
    Cmax = 1;
else
    Cmax = max(Cvalidos);
end

Resumen.EstabilidadScore = NaN(height(Resumen),1);
Resumen.DeteccionScore = NaN(height(Resumen),1);

for i = 1:height(Resumen)

    if ~isnan(D(i))
        if D(i) == 0
            Resumen.EstabilidadScore(i) = 100;
        else
            Resumen.EstabilidadScore(i) = 100 * Dmin / D(i);
        end
    end

    if ~isnan(C(i))
        Resumen.DeteccionScore(i) = 100 * C(i) / max(Cmax, eps);
    end

end

Resumen.EstabilidadScore = min(Resumen.EstabilidadScore, 100);
Resumen.DeteccionScore = min(Resumen.DeteccionScore, 100);

if tipoIndice == "media"

    Resumen.IndiceCompromiso = ...
        0.5 * Resumen.EstabilidadScore + ...
        0.5 * Resumen.DeteccionScore;

elseif tipoIndice == "ponderado"

    sumaPesos = pesoEstabilidad + pesoDeteccion;

    if sumaPesos <= 0
        error("La suma de pesos debe ser mayor que cero.");
    end

    pesoEstabilidad = pesoEstabilidad / sumaPesos;
    pesoDeteccion = pesoDeteccion / sumaPesos;

    Resumen.IndiceCompromiso = ...
        (Resumen.EstabilidadScore .^ pesoEstabilidad) .* ...
        (Resumen.DeteccionScore .^ pesoDeteccion);

else

    Resumen.IndiceCompromiso = ...
        sqrt(Resumen.EstabilidadScore .* Resumen.DeteccionScore);

end

end


%% ========================================================================
%  MODA ROBUSTA Y PREPROCESADO
%% ========================================================================

function [modaHz, xRed] = calcularModaRobusta( ...
    x, ...
    resolucion, ...
    nDescartar, ...
    usarSoloParteFinal, ...
    nFinales, ...
    usarFiltroMAD, ...
    Kmad)

x = x(:);
x = x(~isnan(x));
x = x(x > 0);

% ----------------------------------------------------------
% 1) Descartar las primeras muestras del bloque.
% ----------------------------------------------------------
if numel(x) > nDescartar
    x = x(nDescartar+1:end);
else
    x = [];
end

if isempty(x)
    modaHz = NaN;
    xRed = [];
    return;
end

% ----------------------------------------------------------
% 2) Usar solo la parte final estable del bloque.
% ----------------------------------------------------------
if usarSoloParteFinal && numel(x) > nFinales
    x = x(end-nFinales+1:end);
end

if isempty(x)
    modaHz = NaN;
    xRed = [];
    return;
end

% ----------------------------------------------------------
% 3) Filtro robusto opcional basado en MAD.
% ----------------------------------------------------------
if usarFiltroMAD && numel(x) > 20

    med0 = median(x);
    mad0 = median(abs(x - med0));

    if mad0 > 0
        idx = abs(x - med0) <= Kmad * mad0;
        x = x(idx);
    end

end

if isempty(x)
    modaHz = NaN;
    xRed = [];
    return;
end

% ----------------------------------------------------------
% 4) Redondeo segun la resolucion de la ventana y calculo
%    de la moda. Si hay varias modas, se elige la mas proxima
%    a la mediana.
% ----------------------------------------------------------
xRed = round(x ./ resolucion) .* resolucion;
medianaHz = median(xRed);

[u, ~, ic] = unique(xRed);
cuentas = accumarray(ic, 1);

cuentaMax = max(cuentas);
candidatas = u(cuentas == cuentaMax);

[~, idxMejor] = min(abs(candidatas - medianaHz));
modaHz = candidatas(idxMejor);

end


function ady = encontrarAdyacentes(k)

if k == 1
    ady = 2;
elseif k == 2
    ady = [1 3];
elseif k == 3
    ady = [2 4];
elseif k == 4
    ady = 3;
else
    ady = [];
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
%  CONFIGURACIONES
%% ========================================================================

function ConfigInfo = crearTablaConfiguraciones(ventanasOrden, etapasOrden)

ConfigID = zeros(0,1);
Ventana = strings(0,1);
Etapas = zeros(0,1);
ConfigLabel = strings(0,1);

contador = 0;

for v = 1:numel(ventanasOrden)
    for e = 1:numel(etapasOrden)

        if ventanasOrden(v) == "100ms" && etapasOrden(e) == 3
            continue;
        end

        contador = contador + 1;

        ConfigID(end+1,1) = contador; %#ok<AGROW>
        Ventana(end+1,1) = ventanasOrden(v); %#ok<AGROW>
        Etapas(end+1,1) = etapasOrden(e); %#ok<AGROW>
        ConfigLabel(end+1,1) = ...
            ventanasOrden(v) + "-" + string(etapasOrden(e)) + "e"; %#ok<AGROW>

    end
end

ConfigInfo = table(ConfigID, Ventana, Etapas, ConfigLabel);

end


function id = calcularConfigID(ventana, etapas, ventanasOrden, etapasOrden)

ventana = string(ventana);
etapas = double(etapas);

id = NaN(numel(ventana), 1);
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

if numel(id) == 1
    id = id(1);
end

end


%% ========================================================================
%  LECTURA DE ARCHIVOS
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
%  MEJORES CONFIGURACIONES Y GRAFICA
%% ========================================================================

function MejorPorPCB = seleccionarMejorPorPCB(Ranking)

pcbs = unique(Ranking.PCB, 'stable');
MejorPorPCB = table();

for i = 1:numel(pcbs)

    T = Ranking(Ranking.PCB == pcbs(i), :);

    T = sortrows( ...
        T, ...
        {'IndiceCompromiso','DeteccionScore','EstabilidadScore'}, ...
        {'descend','descend','descend'});

    MejorPorPCB = [MejorPorPCB; T(1,:)]; %#ok<AGROW>

end

MejorPorPCB = sortrows( ...
    MejorPorPCB, ...
    {'IndiceCompromiso','DeteccionScore','EstabilidadScore'}, ...
    {'descend','descend','descend'});

end


function graficarPuntosGeneral(Resumen, MejorPorPCB, ConfigInfo, usarOffset, ampOffset)

fig = figure( ...
    'Name', 'Compromiso estabilidad-deteccion', ...
    'NumberTitle', 'off');

hold on;
grid on;

pcbs = unique(Resumen.PCB, 'stable');
colores = lines(numel(pcbs));

if usarOffset && numel(pcbs) > 1
    offsets = linspace(-ampOffset, ampOffset, numel(pcbs));
else
    offsets = zeros(1,numel(pcbs));
end

hPuntosPCB = gobjects(numel(pcbs),1);

for i = 1:numel(pcbs)

    pcb = pcbs(i);
    T = Resumen(Resumen.PCB == pcb, :);
    T = sortrows(T, 'ConfigID');

    x = T.ConfigID + offsets(i);
    y = T.IndiceCompromiso;

    hPuntosPCB(i) = scatter( ...
        x, ...
        y, ...
        70, ...
        colores(i,:), ...
        'filled', ...
        'DisplayName', strrep(char(pcb), '_', '\_'));

    hPuntosPCB(i).UserData = gobjects(0);

end

% Mejor configuracion de cada PCB.
for i = 1:height(MejorPorPCB)

    pcb = MejorPorPCB.PCB(i);
    idxPcb = find(pcbs == pcb, 1);

    x = MejorPorPCB.ConfigID(i) + offsets(idxPcb);
    y = MejorPorPCB.IndiceCompromiso(i);

    hMejor = scatter( ...
        x, ...
        y, ...
        165, ...
        'd', ...
        'MarkerEdgeColor', 'k', ...
        'MarkerFaceColor', colores(idxPcb,:), ...
        'LineWidth', 1.5, ...
        'HandleVisibility', 'off');

    hPuntosPCB(idxPcb).UserData = [hPuntosPCB(idxPcb).UserData, hMejor];

end

% Mejor configuracion global.
[~, idxBest] = max(Resumen.IndiceCompromiso);
best = Resumen(idxBest,:);
idxPcbBest = find(pcbs == best.PCB, 1);

xBest = best.ConfigID + offsets(idxPcbBest);
yBest = best.IndiceCompromiso;

hGlobal = scatter( ...
    xBest, ...
    yBest, ...
    260, ...
    'p', ...
    'filled', ...
    'MarkerFaceColor', colores(idxPcbBest,:), ...
    'MarkerEdgeColor', 'k', ...
    'LineWidth', 1.8, ...
    'HandleVisibility', 'off');

hTextoGlobal = text( ...
    xBest, ...
    yBest, ...
    "  " + best.PCB + " | " + best.ConfigLabel, ...
    'Interpreter', 'none', ...
    'FontWeight', 'bold', ...
    'FontSize', 9);

hPuntosPCB(idxPcbBest).UserData = ...
    [hPuntosPCB(idxPcbBest).UserData, hGlobal, hTextoGlobal];

xlim([0.5 15.5]);
ylim([0 105]);

xticks(ConfigInfo.ConfigID);
xticklabels(ConfigInfo.ConfigLabel);
xtickangle(45);

xlabel('Condicion de medida');
ylabel('Indice de compromiso estabilidad-deteccion [0-100]');
title('Comparacion general entre estabilidad y deteccion de cambios', 'Interpreter', 'none');

lgd = legend('Location', 'bestoutside');
lgd.ItemHitFcn = @toggleVisibilidadDesdeLeyenda;

annotation( ...
    fig, ...
    'textbox', ...
    [0.13 0.01 0.75 0.04], ...
    'String', 'Pulsa sobre una PCB en la leyenda para mostrar u ocultar sus puntos.', ...
    'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', ...
    'FontSize', 9);

end


function toggleVisibilidadDesdeLeyenda(~, event)

h = event.Peer;

if strcmp(h.Visible, 'on')
    nuevoEstado = 'off';
else
    nuevoEstado = 'on';
end

h.Visible = nuevoEstado;

asociados = h.UserData;

if isempty(asociados)
    return;
end

for k = 1:numel(asociados)
    if isgraphics(asociados(k))
        asociados(k).Visible = nuevoEstado;
    end
end

end