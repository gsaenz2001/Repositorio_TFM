function Analisis_Condiciones_Ambientales_Compromiso()
% ANALISIS DE CONDICIONES AMBIENTALES COMO ANALISIS DE COMPROMISO
%
% Cada archivo ambiental se trata como una serie independiente.
% La grafica permite mover manualmente los puntos con el raton.
%
% Click izquierdo sobre un punto -> arrastrar verticalmente -> soltar.
%
% Se conserva:
%   IndiceCompromiso_Original
%
% Se modifica en la grafica:
%   IndiceCompromiso_Grafica

clc;
close all;
format compact;
format short g;

%% =========================================================
%  CONFIGURACION
%% =========================================================

carpeta = "D:\TFM\PYTHON\CONDICONES_AMBIENTALES_M2_2L_16";
% Revisa si tu carpeta se llama CONDICONES o CONDICIONES.

nombreAnalisis = "CONDICIONES_AMBIENTALES";

ventanasOrden = ["100ms", "10ms", "1ms", "100us"];
etapasOrden   = [3, 5, 51, 101];

condicionesDescartadas = [
    "100ms", "3"
];

numMuestrasInicialesDescartar = 250;

usarSoloParteFinalBloque = false;
numMuestrasFinalesUsar = 300;

usarFiltroRobustoMAD = false;
Kmad = 8;

tipoIndice = "geometrico";

usarDesplazamientoHorizontal = false;
amplitudDesplazamiento = 0;

%% =========================================================
%  1. LEER DATOS
%% =========================================================

fprintf("\n============================================================\n");
fprintf("ANALISIS DE COMPROMISO CON CONDICIONES AMBIENTALES\n");
fprintf("Analisis: %s\n", char(nombreAnalisis));
fprintf("Carpeta: %s\n", char(carpeta));
fprintf("Primeras muestras descartadas: %d\n", numMuestrasInicialesDescartar);
fprintf("Indice: %s\n", char(tipoIndice));
fprintf("============================================================\n");

Datos = leerCarpetaAmbiental(carpeta);

if isempty(Datos)
    error("No se han leido datos. Revisa la carpeta y el formato de los archivos.");
end

Datos = filtrarCondicionesDescartadas(Datos, condicionesDescartadas);

Datos.ConfigID = calcularConfigID(Datos.Ventana, Datos.Etapas, ventanasOrden, etapasOrden);
Datos.ConfigLabel = Datos.Ventana + "-" + string(Datos.Etapas) + "e";

Datos = sortrows(Datos, {'PCB','EstadoSonda','ConfigID','Idx'});

ConfigInfo = crearTablaConfiguraciones(ventanasOrden, etapasOrden);

fprintf("\nCondiciones ambientales leidas:\n");
disp(unique(Datos(:, {'PCB','PCB_Original','Temperatura_C','Humedad_pct','Presion_hPa'}), 'rows'));

fprintf("\nConfiguraciones analizadas:\n");
disp(ConfigInfo);

%% =========================================================
%  2. CALCULAR TABLA FINAL
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

ResumenFinal = normalizarYCalcularIndice(ResumenFinal, tipoIndice);

% Se crean dos columnas:
%   Original: resultado calculado
%   Grafica: valor que se puede mover en la figura
ResumenFinal.IndiceCompromiso_Original = ResumenFinal.IndiceCompromiso;
ResumenFinal.IndiceCompromiso_Grafica = ResumenFinal.IndiceCompromiso;
ResumenFinal.AjusteManual = false(height(ResumenFinal), 1);
ResumenFinal.MotivoAjuste = strings(height(ResumenFinal), 1);

RankingCompromiso = sortrows( ...
    ResumenFinal, ...
    {'IndiceCompromiso_Grafica','DeteccionScore','EstabilidadScore'}, ...
    {'descend','descend','descend'});

RankingCompromiso.Rank = (1:height(RankingCompromiso)).';

%% =========================================================
%  3. MOSTRAR TABLA FINAL
%% =========================================================

columnasMostrar = { ...
    'Rank', ...
    'PCB', ...
    'PCB_Original', ...
    'Temperatura_C', ...
    'Humedad_pct', ...
    'Presion_hPa', ...
    'ConfigID', ...
    'ConfigLabel', ...
    'DispersionSinSonda_pct', ...
    'CambioDirectoMedioAbs_pct', ...
    'CambioAdyacenteMedioAbs_pct', ...
    'AdjSobreDirecto_pct', ...
    'EstabilidadScore', ...
    'DeteccionScore', ...
    'IndiceCompromiso_Original', ...
    'IndiceCompromiso_Grafica', ...
    'AjusteManual', ...
    'MotivoAjuste'};

fprintf("\n============================================================\n");
fprintf("TABLA FINAL: COMPROMISO ESTABILIDAD-DETECCION POR CONDICION AMBIENTAL\n");
fprintf("============================================================\n");
disp(RankingCompromiso(:, columnasMostrar));

fprintf("\n============================================================\n");
fprintf("MEJOR CONFIGURACION GLOBAL SEGUN INDICE DE GRAFICA\n");
fprintf("============================================================\n");
disp(RankingCompromiso(1, columnasMostrar));

%% =========================================================
%  4. GRAFICA GENERAL INTERACTIVA
%% =========================================================

graficarPuntosGeneralMovibles( ...
    ResumenFinal, ...
    ConfigInfo, ...
    usarDesplazamientoHorizontal, ...
    amplitudDesplazamiento);

%% =========================================================
%  5. EXPORTAR AL WORKSPACE
%% =========================================================

assignin('base', 'DatosAmbientales', Datos);
assignin('base', 'ResumenCompromisoAmbiental', ResumenFinal);
assignin('base', 'RankingCompromisoAmbiental', RankingCompromiso);
assignin('base', 'ConfigInfoAmbiental', ConfigInfo);

fprintf("\n============================================================\n");
fprintf("PROCESO COMPLETADO\n");
fprintf("Variables en workspace:\n");
fprintf("  DatosAmbientales\n");
fprintf("  ResumenCompromisoAmbiental\n");
fprintf("  RankingCompromisoAmbiental\n");
fprintf("  ConfigInfoAmbiental\n");
fprintf("\nCuando muevas puntos en la grafica se exportara tambien:\n");
fprintf("  ResumenCompromisoAmbiental_Ajustado\n");
fprintf("  RankingCompromisoAmbiental_Ajustado\n");
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
PCB_Original = strings(0,1);
Temperatura_C = zeros(0,1);
Humedad_pct = zeros(0,1);
Presion_hPa = zeros(0,1);

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

            cambiosDirectos = NaN(1,4);
            cambiosAdyPorSonda = NaN(1,4);

            for k = 1:4

                estado = "SONDA_P" + string(k);
                Tsonda = Tcond(Tcond.EstadoSonda == estado, :);

                if isempty(Tsonda)
                    continue;
                end

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
            PCB_Original(end+1,1) = Tcond.PCB_Original(1); %#ok<AGROW>
            Temperatura_C(end+1,1) = Tcond.Temperatura_C(1); %#ok<AGROW>
            Humedad_pct(end+1,1) = Tcond.Humedad_pct(1); %#ok<AGROW>
            Presion_hPa(end+1,1) = Tcond.Presion_hPa(1); %#ok<AGROW>

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
    PCB_Original, ...
    Temperatura_C, ...
    Humedad_pct, ...
    Presion_hPa, ...
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

%% ========================================================================
%  NORMALIZACION E INDICE
%% ========================================================================

function Resumen = normalizarYCalcularIndice(Resumen, tipoIndice)

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

else

    Resumen.IndiceCompromiso = ...
        sqrt(Resumen.EstabilidadScore .* Resumen.DeteccionScore);

end

end

%% ========================================================================
%  LECTURA DE ARCHIVOS AMBIENTALES
%% ========================================================================

function Datos = leerCarpetaAmbiental(carpeta)

d = dir(fullfile(carpeta, "*.txt"));

Datos = table();

for i = 1:numel(d)

    nombre = string(d(i).name);
    archivo = string(fullfile(d(i).folder, d(i).name));

    [ok, temperatura, humedad, presion, nombreBase] = parsearNombreAmbiental(nombre);

    if ~ok
        warning("Archivo ignorado por no tener formato temperatura_humedad_presion: %s", char(nombre));
        continue;
    end

    fprintf("Leyendo: %s -> T=%.1f C, H=%.1f %%, P=%.1f hPa\n", ...
        char(nombre), temperatura, humedad, presion);

    T = leerArchivoSonda(archivo);

    if isempty(T)
        warning("Archivo sin datos validos: %s", char(nombre));
        continue;
    end

    n = height(T);

    T.Archivo = repmat(nombreBase, n, 1);
    T.PCB_Original = T.PCB;

    T.PCB = repmat(nombreBase, n, 1);

    T.Temperatura_C = repmat(temperatura, n, 1);
    T.Humedad_pct = repmat(humedad, n, 1);
    T.Presion_hPa = repmat(presion, n, 1);

    Datos = [Datos; T]; %#ok<AGROW>

end

end

function [ok, temperatura, humedad, presion, nombreBase] = parsearNombreAmbiental(nombre)

[~, base, ~] = fileparts(char(nombre));
nombreBase = string(base);

nums = regexp(nombreBase, "[-+]?\d+(?:[.,]\d+)?", "match");

ok = false;
temperatura = NaN;
humedad = NaN;
presion = NaN;

if numel(nums) < 3
    return;
end

temperatura = str2double(strrep(nums{1}, ",", "."));
humedad     = str2double(strrep(nums{2}, ",", "."));
presion     = str2double(strrep(nums{3}, ",", "."));

ok = ~(isnan(temperatura) || isnan(humedad) || isnan(presion));

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

if isempty(F)
    T = table();
    return;
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

%% ========================================================================
%  MODA ROBUSTA
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

if usarSoloParteFinal && numel(x) > nFinales
    x = x(end-nFinales+1:end);
end

if isempty(x)
    modaHz = NaN;
    xRed = [];
    return;
end

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
%  GRAFICA INTERACTIVA CON PUNTOS MOVIBLES
%% ========================================================================

function graficarPuntosGeneralMovibles(Resumen, ConfigInfo, usarOffset, ampOffset)

fig = figure( ...
    'Name', 'Compromiso estabilidad-deteccion por condicion ambiental', ...
    'NumberTitle', 'off');

hold on;
grid on;

fig.UserData.Resumen = Resumen;
fig.UserData.Drag = [];

pcbs = unique(Resumen.PCB, 'stable');
colores = lines(numel(pcbs));

if usarOffset && numel(pcbs) > 1
    offsets = linspace(-ampOffset, ampOffset, numel(pcbs));
else
    offsets = zeros(1,numel(pcbs));
end

for i = 1:numel(pcbs)

    pcb = pcbs(i);

    filas = find(Resumen.PCB == pcb);
    [~, orden] = sort(Resumen.ConfigID(filas));
    filas = filas(orden);

    T = Resumen(filas, :);

    x = T.ConfigID + offsets(i);
    y = T.IndiceCompromiso_Grafica;

    etiqueta = sprintf('%s | %.1f C | %.1f %% | %.1f hPa', ...
        pcb, ...
        T.Temperatura_C(1), ...
        T.Humedad_pct(1), ...
        T.Presion_hPa(1));

    h = scatter( ...
        x, ...
        y, ...
        70, ...
        colores(i,:), ...
        'filled', ...
        'DisplayName', etiqueta, ...
        'ButtonDownFcn', @iniciarArrastrePunto, ...
        'HitTest', 'on', ...
        'PickableParts', 'all');

    info.rowIndices = filas;
    info.pcb = pcb;
    h.UserData = info;

end

xlim([0.5 15.5]);
ylim([0 105]);

xticks(ConfigInfo.ConfigID);
xticklabels(ConfigInfo.ConfigLabel);
xtickangle(45);

xlabel('Condicion de medida');
ylabel('Indice de compromiso estabilidad-deteccion [0-100]');
title('Comparacion del indice de compromiso bajo distintas condiciones ambientales', 'Interpreter', 'none');

lgd = legend('Location', 'bestoutside', 'Interpreter', 'none');
lgd.ItemHitFcn = @toggleVisibilidadDesdeLeyenda;

annotation( ...
    fig, ...
    'textbox', ...
    [0.13 0.01 0.75 0.04], ...
    'String', 'Click sobre un punto y arrastra verticalmente para modificarlo. Al soltar se exporta la tabla ajustada al workspace.', ...
    'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', ...
    'FontSize', 9);

end

function iniciarArrastrePunto(src, ~)

fig = ancestor(src, 'figure');
ax = ancestor(src, 'axes');

cp = ax.CurrentPoint;
xClick = cp(1,1);
yClick = cp(1,2);

xData = src.XData;
yData = src.YData;

xl = xlim(ax);
yl = ylim(ax);

dx = (xData - xClick) ./ max(diff(xl), eps);
dy = (yData - yClick) ./ max(diff(yl), eps);

[~, idxPunto] = min(dx.^2 + dy.^2);

info = src.UserData;
rowIndex = info.rowIndices(idxPunto);

drag.src = src;
drag.idxPunto = idxPunto;
drag.rowIndex = rowIndex;

ud = fig.UserData;
ud.Drag = drag;
fig.UserData = ud;

fig.WindowButtonMotionFcn = @moverPunto;
fig.WindowButtonUpFcn = @soltarPunto;

moverPunto(fig, []);

end

function moverPunto(fig, ~)

ud = fig.UserData;

if ~isfield(ud, 'Drag') || isempty(ud.Drag)
    return;
end

drag = ud.Drag;
src = drag.src;

if ~isgraphics(src)
    return;
end

ax = ancestor(src, 'axes');
cp = ax.CurrentPoint;

yNuevo = cp(1,2);
yNuevo = max(0, min(100, yNuevo));

yData = src.YData;
yData(drag.idxPunto) = yNuevo;
src.YData = yData;

ud.Resumen.IndiceCompromiso_Grafica(drag.rowIndex) = yNuevo;
ud.Resumen.AjusteManual(drag.rowIndex) = true;
ud.Resumen.MotivoAjuste(drag.rowIndex) = "movido manualmente en grafica";

fig.UserData = ud;

drawnow limitrate;

end

function soltarPunto(fig, ~)

ud = fig.UserData;

if ~isfield(ud, 'Drag') || isempty(ud.Drag)
    return;
end

rowIndex = ud.Drag.rowIndex;
ResumenAjustado = ud.Resumen;

RankingAjustado = sortrows( ...
    ResumenAjustado, ...
    {'IndiceCompromiso_Grafica','DeteccionScore','EstabilidadScore'}, ...
    {'descend','descend','descend'});

RankingAjustado.Rank = (1:height(RankingAjustado)).';

assignin('base', 'ResumenCompromisoAmbiental_Ajustado', ResumenAjustado);
assignin('base', 'RankingCompromisoAmbiental_Ajustado', RankingAjustado);

fprintf("\nPunto actualizado:\n");
fprintf("  PCB/condicion: %s\n", char(ResumenAjustado.PCB(rowIndex)));
fprintf("  Configuracion: %s\n", char(ResumenAjustado.ConfigLabel(rowIndex)));
fprintf("  Original     : %.4f\n", ResumenAjustado.IndiceCompromiso_Original(rowIndex));
fprintf("  Grafica      : %.4f\n", ResumenAjustado.IndiceCompromiso_Grafica(rowIndex));
fprintf("Tablas exportadas al workspace:\n");
fprintf("  ResumenCompromisoAmbiental_Ajustado\n");
fprintf("  RankingCompromisoAmbiental_Ajustado\n");

ud.Drag = [];
fig.UserData = ud;

fig.WindowButtonMotionFcn = '';
fig.WindowButtonUpFcn = '';

end

function toggleVisibilidadDesdeLeyenda(~, event)

h = event.Peer;

if strcmp(h.Visible, 'on')
    h.Visible = 'off';
else
    h.Visible = 'on';
end

end