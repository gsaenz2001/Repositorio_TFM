function Analisis_Cambios_Sonda_Moda()

clc; close all;
format compact;
format short g;

%% =========================================================
%  ANALISIS DE CAMBIOS CON SONDA USANDO MODA
%
%  Este script analiza SOLO el efecto de la sonda.
%  No mezcla estabilidad.
%
%  Para cada PCB, ventana, etapas, estado de sonda y pista:
%     - Calcula la moda de frecuencia sin sonda
%     - Calcula la moda de frecuencia con sonda
%     - Compara ambas modas pista a pista
%
%  Metricas:
%     DeltaModa_Hz  = moda_con_sonda - moda_sin_sonda
%     DeltaModa_pct = 100 * DeltaModa_Hz / moda_sin_sonda
%
%  Para cada condicion:
%     - Cambio directo: sonda en Pk y medida en Pk
%     - Cambio en otras pistas: sonda en Pk y medida en Pj, j ~= k
%     - Cambio adyacente: pistas fisicamente contiguas
%     - Selectividad = cambio_directo / cambio_otras
%
%% =========================================================


%% ===================== CONFIGURACION =====================

carpeta = "D:\TFM\PYTHON\CAMBIOS_SONDA";

% ==========================================================
% CAMBIA SOLO ESTO
% ==========================================================

% ---- TODAS LAS PCBs ----
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
% Elegir una sonda concreta o todas
% ----------------------------------------------------------

estadoAnalisis = "TODAS";

% estadoAnalisis = "SONDA_P1";
% estadoAnalisis = "SONDA_P2";
% estadoAnalisis = "SONDA_P3";
% estadoAnalisis = "SONDA_P4";


% ----------------------------------------------------------
% Condiciones experimentales
% ----------------------------------------------------------

ventanasOrden = ["100ms", "10ms", "1ms", "100us"];
etapasOrden   = [3, 5, 51, 101];

% Condicion descartada tras estabilidad
condicionesDescartadas = [
    "100ms", "3"
];

numPistas = 4;


% ----------------------------------------------------------
% Limpieza de datos
% ----------------------------------------------------------

% Descarta primeras muestras de cada bloque por posibles transitorios
numMuestrasInicialesDescartar = 10;

% Filtro robusto para quitar cambios de bitstream, arranques raros o saltos
usarFiltroClusterPrincipal = true;

% Se conservan muestras cercanas a la mediana:
% abs(x - mediana) <= Kmad * MAD
Kmad = 8;

% Redondear antes de calcular la moda según resolucion de ventana
redondearSegunVentana = true;


% ----------------------------------------------------------
% Visualizacion
% ----------------------------------------------------------

mostrarMatricesMejorCondicion = true;
mostrarMatricesTodasCondiciones = false;

topGlobalMostrar = 20;

% Criterio principal del ranking:
% "DIRECTO"    -> ordena por mayor cambio directo
% "SELECTIVO"  -> ordena por mayor cambio directo y menor acoplo
criterioRanking = "DIRECTO";

% ==========================================================


%% =========================================================
%  LECTURA DE DATOS
%% =========================================================

fprintf("\n============================================================\n");
fprintf("ANALISIS CAMBIOS CON SONDA MEDIANTE MODA\n");
fprintf("Analisis: %s\n", nombreAnalisis);
fprintf("Estado de sonda: %s\n", estadoAnalisis);
fprintf("============================================================\n");

Datos = table();

for i = 1:numel(pcbsAnalisis)

    pcb = pcbsAnalisis(i);

    archivoTxt = fullfile(carpeta, pcb + "_sonda.txt");
    archivoSinExt = fullfile(carpeta, pcb + "_sonda");

    if isfile(archivoTxt)
        archivo = archivoTxt;
    elseif isfile(archivoSinExt)
        archivo = archivoSinExt;
    else
        warning("No se ha encontrado archivo para %s", pcb);
        continue;
    end

    fprintf("\nLeyendo: %s\n", archivo);

    T = leerArchivoSonda(archivo);

    if isempty(T)
        warning("Archivo vacio o sin datos validos: %s", archivo);
        continue;
    end

    Datos = [Datos; T];

end

if isempty(Datos)
    error("No se han leido datos. Revisa carpeta y nombres.");
end

fprintf("\nMuestras leidas: %d\n", height(Datos));


%% =========================================================
%  FILTRAR CONDICIONES DESCARTADAS
%% =========================================================

Datos = filtrarCondicionesDescartadas(Datos, condicionesDescartadas);

fprintf("Muestras tras descartar condiciones no usadas: %d\n", height(Datos));


%% =========================================================
%  CALCULAR MODA POR BLOQUE
%% =========================================================

StatsModa = calcularModaPorBloque( ...
    Datos, ...
    numPistas, ...
    numMuestrasInicialesDescartar, ...
    usarFiltroClusterPrincipal, ...
    Kmad, ...
    redondearSegunVentana);

fprintf("\nBloques con moda calculada: %d\n", height(StatsModa));

fprintf("\nEjemplo de estadisticos de moda:\n");
disp(StatsModa(1:min(12,height(StatsModa)), :));


%% =========================================================
%  CALCULAR CAMBIOS RESPECTO A SIN_SONDA
%% =========================================================

Cambios = calcularCambiosModa(StatsModa, estadoAnalisis);

fprintf("\nComparaciones sonda vs SIN_SONDA: %d\n", height(Cambios));

fprintf("\nEjemplo de cambios calculados:\n");
varsCambios = { ...
    'PCB', ...
    'EstadoSonda', ...
    'Ventana', ...
    'Etapas', ...
    'PistaMedida', ...
    'TipoEfecto', ...
    'ModaSinSonda_Hz', ...
    'ModaConSonda_Hz', ...
    'DeltaModa_Hz', ...
    'DeltaModa_pct', ...
    'DeltaModaAbs_pct'};

mostrarTablaSegura(Cambios(1:min(16,height(Cambios)), :), varsCambios);


%% =========================================================
%  RESUMEN POR ESTADO DE SONDA
%% =========================================================

ResumenSonda = resumirPorEstadoSonda(Cambios);

fprintf("\n============================================================\n");
fprintf("RESUMEN POR ESTADO DE SONDA\n");
fprintf("============================================================\n");

varsResumenSonda = { ...
    'PCB', ...
    'EstadoSonda', ...
    'Ventana', ...
    'Etapas', ...
    'CambioDirectoAbs_pct', ...
    'CambioOtrasAbs_pct', ...
    'CambioAdyacenteAbs_pct', ...
    'DeltaMedia4Abs_pct', ...
    'Selectividad'};

mostrarTablaSegura(ResumenSonda(1:min(20,height(ResumenSonda)), :), varsResumenSonda);


%% =========================================================
%  RESUMEN POR CONFIGURACION
%% =========================================================

ResumenConfig = resumirPorConfiguracion(ResumenSonda);

if criterioRanking == "SELECTIVO"
    ResumenConfig = sortrows(ResumenConfig, "IndiceSelectivo", "descend");
else
    ResumenConfig = sortrows(ResumenConfig, "CambioDirectoMedioAbs_pct", "descend");
end


%% =========================================================
%  RANKING POR PCB
%% =========================================================

fprintf("\n============================================================\n");
fprintf("RANKING POR PCB\n");
fprintf("Criterio principal: %s\n", criterioRanking);
fprintf("============================================================\n");

varsRanking = { ...
    'PCB', ...
    'Ventana', ...
    'Etapas', ...
    'CambioDirectoMedioAbs_pct', ...
    'CambioOtrasMedioAbs_pct', ...
    'CambioAdyacenteMedioAbs_pct', ...
    'DeltaMedia4MedioAbs_pct', ...
    'SelectividadMedia', ...
    'PistaMasSensible', ...
    'MejorEstadoSonda', ...
    'IndiceSelectivo'};

pcbs = unique(ResumenConfig.PCB, 'stable');

MejorPorPCB = table();

for i = 1:numel(pcbs)

    pcb = pcbs(i);
    Tpcb = ResumenConfig(ResumenConfig.PCB == pcb, :);

    if criterioRanking == "SELECTIVO"
        Tpcb = sortrows(Tpcb, "IndiceSelectivo", "descend");
    else
        Tpcb = sortrows(Tpcb, "CambioDirectoMedioAbs_pct", "descend");
    end

    fprintf("\n------------------------------------------------------------\n");
    fprintf("PCB: %s\n", pcb);
    fprintf("------------------------------------------------------------\n");

    mostrarTablaSegura(Tpcb, varsRanking);

    MejorPorPCB = [MejorPorPCB; Tpcb(1,:)];

end


%% =========================================================
%  MEJOR CONFIGURACION DE CADA PCB
%% =========================================================

if criterioRanking == "SELECTIVO"
    MejorPorPCB = sortrows(MejorPorPCB, "IndiceSelectivo", "descend");
else
    MejorPorPCB = sortrows(MejorPorPCB, "CambioDirectoMedioAbs_pct", "descend");
end

fprintf("\n============================================================\n");
fprintf("MEJOR CONFIGURACION DE CADA PCB\n");
fprintf("============================================================\n");

mostrarTablaSegura(MejorPorPCB, varsRanking);


%% =========================================================
%  RANKING GLOBAL
%% =========================================================

fprintf("\n============================================================\n");
fprintf("TOP GLOBAL DE CONFIGURACIONES\n");
fprintf("============================================================\n");

nTop = min(topGlobalMostrar, height(ResumenConfig));

mostrarTablaSegura(ResumenConfig(1:nTop,:), varsRanking);


%% =========================================================
%  MATRICES 4x4 DE CAMBIO
%% =========================================================

if mostrarMatricesMejorCondicion

    fprintf("\n============================================================\n");
    fprintf("MATRICES 4x4 DE LA MEJOR CONDICION DE CADA PCB\n");
    fprintf("Filas = posicion de la sonda; columnas = pista medida\n");
    fprintf("Diagonal = efecto directo\n");
    fprintf("============================================================\n");

    for i = 1:height(MejorPorPCB)

        pcb = MejorPorPCB.PCB(i);
        ventana = MejorPorPCB.Ventana(i);
        etapas = MejorPorPCB.Etapas(i);

        fprintf("\n------------------------------------------------------------\n");
        fprintf("PCB: %s | Ventana: %s | Etapas: %d\n", pcb, ventana, etapas);
        fprintf("------------------------------------------------------------\n");

        imprimirMatrices4x4(Cambios, pcb, ventana, etapas);

    end

end

if mostrarMatricesTodasCondiciones

    fprintf("\n============================================================\n");
    fprintf("MATRICES 4x4 DE TODAS LAS CONDICIONES\n");
    fprintf("============================================================\n");

    for i = 1:height(ResumenConfig)

        pcb = ResumenConfig.PCB(i);
        ventana = ResumenConfig.Ventana(i);
        etapas = ResumenConfig.Etapas(i);

        fprintf("\n------------------------------------------------------------\n");
        fprintf("PCB: %s | Ventana: %s | Etapas: %d\n", pcb, ventana, etapas);
        fprintf("------------------------------------------------------------\n");

        imprimirMatrices4x4(Cambios, pcb, ventana, etapas);

    end

end


%% =========================================================
%  GRAFICAS DE PUNTOS
%% =========================================================

graficarPuntosPorPCB(ResumenConfig, pcbs);

graficarPuntosGlobal(ResumenConfig, MejorPorPCB);

fprintf("\nProceso completado.\n");
fprintf("Este analisis usa solo cambios con sonda, no estabilidad.\n");

end


%% ========================================================================
%  FUNCIONES
%% ========================================================================

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

        PCB(end+1,1) = metaPCB;
        EstadoSonda(end+1,1) = metaEstado;
        Ventana(end+1,1) = metaVentana;
        Etapas(end+1,1) = metaEtapas;
        Idx(end+1,1) = idx;
        F(end+1,:) = freqs;

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

if isempty(condicionesDescartadas)
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


function StatsModa = calcularModaPorBloque(Datos, numPistas, nDescartar, usarCluster, Kmad, redondearSegunVentana)

comb = unique(Datos(:, {'PCB', 'EstadoSonda', 'Ventana', 'Etapas'}));

StatsModa = table();

for i = 1:height(comb)

    idxBloque = ...
        Datos.PCB == comb.PCB(i) & ...
        Datos.EstadoSonda == comb.EstadoSonda(i) & ...
        Datos.Ventana == comb.Ventana(i) & ...
        Datos.Etapas == comb.Etapas(i);

    Tbloque = Datos(idxBloque,:);

    for p = 1:numPistas

        nombreFreq = "Freq" + string(p);
        x = Tbloque.(nombreFreq);

        x = limpiarFrecuencias(x, nDescartar, usarCluster, Kmad);

        resolucionHz = resolucionVentanaHz(comb.Ventana(i));

        if redondearSegunVentana && ~isempty(x)
            xModa = round(x / resolucionHz) * resolucionHz;
        else
            xModa = x;
        end

        if isempty(xModa)
            modaHz = NaN;
            medianaHz = NaN;
            madHz = NaN;
            nValidas = 0;
            porcentajeModa = NaN;
        else
            [modaHz, porcentajeModa] = modaRobusta(xModa);
            medianaHz = median(xModa, 'omitnan');
            madHz = median(abs(xModa - medianaHz), 'omitnan');
            nValidas = numel(xModa);
        end

        fila = table( ...
            comb.PCB(i), ...
            comb.EstadoSonda(i), ...
            comb.Ventana(i), ...
            comb.Etapas(i), ...
            p, ...
            "P" + string(p), ...
            modaHz, ...
            medianaHz, ...
            madHz, ...
            nValidas, ...
            porcentajeModa, ...
            resolucionHz, ...
            'VariableNames', { ...
                'PCB', ...
                'EstadoSonda', ...
                'Ventana', ...
                'Etapas', ...
                'Pista', ...
                'NombrePista', ...
                'Moda_Hz', ...
                'Mediana_Hz', ...
                'MAD_Hz', ...
                'NumMuestrasValidas', ...
                'PorcentajeModa', ...
                'Resolucion_Hz'});

        StatsModa = [StatsModa; fila];

    end

end

end


function x = limpiarFrecuencias(x, nDescartar, usarCluster, Kmad)

x = x(:);
x = x(~isnan(x));
x = x(x > 0);

if numel(x) > nDescartar
    x = x(nDescartar+1:end);
end

if isempty(x)
    return;
end

if usarCluster && numel(x) > 20

    med = median(x, 'omitnan');
    mad0 = median(abs(x - med), 'omitnan');

    if mad0 > 0
        idx = abs(x - med) <= Kmad * mad0;
        x = x(idx);
    end

end

end


function [m, porcentaje] = modaRobusta(x)

x = x(:);
x = x(~isnan(x));

if isempty(x)
    m = NaN;
    porcentaje = NaN;
    return;
end

[valores, ~, ic] = unique(x);
conteos = accumarray(ic, 1);

maxConteo = max(conteos);
candidatas = valores(conteos == maxConteo);

med = median(x, 'omitnan');

[~, idx] = min(abs(candidatas - med));
m = candidatas(idx);

porcentaje = 100 * maxConteo / numel(x);

end


function Cambios = calcularCambiosModa(StatsModa, estadoAnalisis)

Stats0 = StatsModa(StatsModa.EstadoSonda == "SIN_SONDA", :);
StatsS = StatsModa(StatsModa.EstadoSonda ~= "SIN_SONDA", :);

if estadoAnalisis ~= "TODAS"
    StatsS = StatsS(StatsS.EstadoSonda == estadoAnalisis, :);
end

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

    ref = Stats0(find(idx0,1), :);

    moda0 = ref.Moda_Hz;
    modaS = s.Moda_Hz;

    if isnan(moda0) || isnan(modaS) || moda0 <= 0
        continue;
    end

    deltaHz = modaS - moda0;
    deltaAbsHz = abs(deltaHz);

    deltaPct = 100 * deltaHz / moda0;
    deltaAbsPct = abs(deltaPct);

    sondaPista = extraerPistaSonda(s.EstadoSonda);
    pistaMedida = s.Pista;

    if pistaMedida == sondaPista
        tipoEfecto = "DIRECTA";
    elseif abs(pistaMedida - sondaPista) == 1
        tipoEfecto = "ADYACENTE";
    else
        tipoEfecto = "NO_ADYACENTE";
    end

    if pistaMedida ~= sondaPista
        esOtra = true;
    else
        esOtra = false;
    end

    fila = table( ...
        s.PCB, ...
        s.EstadoSonda, ...
        sondaPista, ...
        s.Ventana, ...
        s.Etapas, ...
        pistaMedida, ...
        "P" + string(pistaMedida), ...
        tipoEfecto, ...
        esOtra, ...
        moda0, ...
        modaS, ...
        ref.PorcentajeModa, ...
        s.PorcentajeModa, ...
        deltaHz, ...
        deltaAbsHz, ...
        deltaPct, ...
        deltaAbsPct, ...
        'VariableNames', { ...
            'PCB', ...
            'EstadoSonda', ...
            'SondaPista', ...
            'Ventana', ...
            'Etapas', ...
            'PistaMedida', ...
            'NombrePistaMedida', ...
            'TipoEfecto', ...
            'EsOtraPista', ...
            'ModaSinSonda_Hz', ...
            'ModaConSonda_Hz', ...
            'PorcentajeModaSinSonda', ...
            'PorcentajeModaConSonda', ...
            'DeltaModa_Hz', ...
            'DeltaModaAbs_Hz', ...
            'DeltaModa_pct', ...
            'DeltaModaAbs_pct'});

    Cambios = [Cambios; fila];

end

end


function ResumenSonda = resumirPorEstadoSonda(Cambios)

comb = unique(Cambios(:, {'PCB', 'EstadoSonda', 'SondaPista', 'Ventana', 'Etapas'}));

ResumenSonda = table();

for i = 1:height(comb)

    idx = ...
        Cambios.PCB == comb.PCB(i) & ...
        Cambios.EstadoSonda == comb.EstadoSonda(i) & ...
        Cambios.Ventana == comb.Ventana(i) & ...
        Cambios.Etapas == comb.Etapas(i);

    T = Cambios(idx,:);

    Tdir = T(T.TipoEfecto == "DIRECTA", :);
    Totras = T(T.EsOtraPista == true, :);
    Tady = T(T.TipoEfecto == "ADYACENTE", :);

    cambioDirecto = mean(Tdir.DeltaModaAbs_pct, 'omitnan');
    cambioOtras = mean(Totras.DeltaModaAbs_pct, 'omitnan');
    cambioAdy = mean(Tady.DeltaModaAbs_pct, 'omitnan');

    mediaSin = mean(T.ModaSinSonda_Hz, 'omitnan');
    mediaCon = mean(T.ModaConSonda_Hz, 'omitnan');

    deltaMedia4Pct = 100 * (mediaCon - mediaSin) / mediaSin;
    deltaMedia4AbsPct = abs(deltaMedia4Pct);

    selectividad = cambioDirecto / max(cambioOtras, eps);

    [maxCambio, idxMax] = max(T.DeltaModaAbs_pct);

    pistaMasAfectada = T.NombrePistaMedida(idxMax);

    fila = table( ...
        comb.PCB(i), ...
        comb.EstadoSonda(i), ...
        comb.SondaPista(i), ...
        comb.Ventana(i), ...
        comb.Etapas(i), ...
        cambioDirecto, ...
        cambioOtras, ...
        cambioAdy, ...
        deltaMedia4Pct, ...
        deltaMedia4AbsPct, ...
        selectividad, ...
        pistaMasAfectada, ...
        maxCambio, ...
        'VariableNames', { ...
            'PCB', ...
            'EstadoSonda', ...
            'SondaPista', ...
            'Ventana', ...
            'Etapas', ...
            'CambioDirectoAbs_pct', ...
            'CambioOtrasAbs_pct', ...
            'CambioAdyacenteAbs_pct', ...
            'DeltaMedia4_pct', ...
            'DeltaMedia4Abs_pct', ...
            'Selectividad', ...
            'PistaMasAfectada', ...
            'MaxCambioPistaAbs_pct'});

    ResumenSonda = [ResumenSonda; fila];

end

ResumenSonda = sortrows(ResumenSonda, {'PCB', 'Ventana', 'Etapas', 'EstadoSonda'});

end


function ResumenConfig = resumirPorConfiguracion(ResumenSonda)

comb = unique(ResumenSonda(:, {'PCB', 'Ventana', 'Etapas'}));

ResumenConfig = table();

for i = 1:height(comb)

    idx = ...
        ResumenSonda.PCB == comb.PCB(i) & ...
        ResumenSonda.Ventana == comb.Ventana(i) & ...
        ResumenSonda.Etapas == comb.Etapas(i);

    T = ResumenSonda(idx,:);

    cambioDirectoMedio = mean(T.CambioDirectoAbs_pct, 'omitnan');
    cambioOtrasMedio = mean(T.CambioOtrasAbs_pct, 'omitnan');
    cambioAdyMedio = mean(T.CambioAdyacenteAbs_pct, 'omitnan');
    deltaMedia4Medio = mean(T.DeltaMedia4Abs_pct, 'omitnan');

    selectividadMedia = cambioDirectoMedio / max(cambioOtrasMedio, eps);

    [~, idxMejor] = max(T.CambioDirectoAbs_pct);

    mejorEstadoSonda = T.EstadoSonda(idxMejor);
    pistaMasSensible = "P" + string(T.SondaPista(idxMejor));

    indiceSelectivo = cambioDirectoMedio * selectividadMedia;

    fila = table( ...
        comb.PCB(i), ...
        comb.Ventana(i), ...
        comb.Etapas(i), ...
        cambioDirectoMedio, ...
        cambioOtrasMedio, ...
        cambioAdyMedio, ...
        deltaMedia4Medio, ...
        selectividadMedia, ...
        pistaMasSensible, ...
        mejorEstadoSonda, ...
        indiceSelectivo, ...
        'VariableNames', { ...
            'PCB', ...
            'Ventana', ...
            'Etapas', ...
            'CambioDirectoMedioAbs_pct', ...
            'CambioOtrasMedioAbs_pct', ...
            'CambioAdyacenteMedioAbs_pct', ...
            'DeltaMedia4MedioAbs_pct', ...
            'SelectividadMedia', ...
            'PistaMasSensible', ...
            'MejorEstadoSonda', ...
            'IndiceSelectivo'});

    ResumenConfig = [ResumenConfig; fila];

end

end


function imprimirMatrices4x4(Cambios, pcb, ventana, etapas)

idx = ...
    Cambios.PCB == pcb & ...
    Cambios.Ventana == ventana & ...
    Cambios.Etapas == etapas;

T = Cambios(idx,:);

if isempty(T)
    fprintf("No hay datos para esta condicion.\n");
    return;
end

Mabs = NaN(4,4);
Msigno = NaN(4,4);

for i = 1:height(T)

    fila = T.SondaPista(i);
    col = T.PistaMedida(i);

    if isnan(fila) || isnan(col)
        continue;
    end

    Mabs(fila, col) = T.DeltaModaAbs_pct(i);
    Msigno(fila, col) = T.DeltaModa_pct(i);

end

nombresFilas = {'SONDA_P1', 'SONDA_P2', 'SONDA_P3', 'SONDA_P4'};
nombresCols = {'P1', 'P2', 'P3', 'P4'};

TablaAbs = array2table(Mabs, ...
    'VariableNames', nombresCols, ...
    'RowNames', nombresFilas);

TablaSigno = array2table(Msigno, ...
    'VariableNames', nombresCols, ...
    'RowNames', nombresFilas);

fprintf("\nCambio absoluto de moda [%%]:\n");
disp(TablaAbs);

fprintf("\nCambio con signo de moda [%%]:\n");
disp(TablaSigno);

end


function graficarPuntosPorPCB(ResumenConfig, pcbs)

for i = 1:numel(pcbs)

    pcb = pcbs(i);
    T = ResumenConfig(ResumenConfig.PCB == pcb, :);

    if isempty(T)
        continue;
    end

    figure;
    hold on; grid on;

    etapasUnicas = unique(T.Etapas);
    colores = lines(numel(etapasUnicas));

    for e = 1:numel(etapasUnicas)

        etapa = etapasUnicas(e);
        Te = T(T.Etapas == etapa, :);

        scatter( ...
            Te.SelectividadMedia, ...
            Te.CambioDirectoMedioAbs_pct, ...
            70, ...
            colores(e,:), ...
            'filled', ...
            'DisplayName', string(etapa) + " etapas");

        for k = 1:height(Te)
            etiqueta = Te.Ventana(k) + "-" + string(Te.Etapas(k));
            text( ...
                Te.SelectividadMedia(k), ...
                Te.CambioDirectoMedioAbs_pct(k), ...
                "  " + etiqueta, ...
                'Interpreter', 'none', ...
                'FontSize', 8);
        end

    end

    xlabel("Selectividad = cambio directo / cambio en otras pistas");
    ylabel("Cambio directo medio de la moda [%]");
    title("Cambios con sonda - " + pcb, 'Interpreter', 'none');
    legend('Location','best');

    % En esta grafica: cuanto mas arriba y a la derecha, mejor.
    % Arriba = cambia mas la pista donde coloco la sonda.
    % Derecha = cambia mas la pista directa que las otras.

end

end


function graficarPuntosGlobal(ResumenConfig, MejorPorPCB)

figure;
hold on; grid on;

pcbs = unique(ResumenConfig.PCB, 'stable');
colores = lines(numel(pcbs));

for i = 1:numel(pcbs)

    pcb = pcbs(i);
    T = ResumenConfig(ResumenConfig.PCB == pcb, :);

    scatter( ...
        T.SelectividadMedia, ...
        T.CambioDirectoMedioAbs_pct, ...
        60, ...
        colores(i,:), ...
        'filled', ...
        'DisplayName', pcb);

end

for i = 1:height(MejorPorPCB)

    etiqueta = MejorPorPCB.PCB(i) + " | " + MejorPorPCB.Ventana(i) + "-" + string(MejorPorPCB.Etapas(i));

    text( ...
        MejorPorPCB.SelectividadMedia(i), ...
        MejorPorPCB.CambioDirectoMedioAbs_pct(i), ...
        "  " + etiqueta, ...
        'Interpreter', 'none', ...
        'FontSize', 8, ...
        'FontWeight', 'bold');

end

xlabel("Selectividad = cambio directo / cambio en otras pistas");
ylabel("Cambio directo medio de la moda [%]");
title("Ranking global de cambios con sonda", 'Interpreter', 'none');
legend('Location','bestoutside');

% En esta grafica: cuanto mas arriba y a la derecha, mejor.
% Solo representa deteccion con sonda, no estabilidad.

end


function p = extraerPistaSonda(estado)

tokens = regexp(char(estado), "SONDA_P(\d+)", "tokens");

if isempty(tokens)
    p = NaN;
else
    p = str2double(tokens{1}{1});
end

end


function r = resolucionVentanaHz(ventana)

switch string(ventana)
    case "100ms"
        r = 10;
    case "10ms"
        r = 100;
    case "1ms"
        r = 1000;
    case "100us"
        r = 10000;
    otherwise
        r = 1;
end

end


function mostrarTablaSegura(T, varsMostrar)

if isempty(T)
    disp("Tabla vacia.");
    return;
end

varsExistentes = T.Properties.VariableNames;
varsValidas = varsMostrar(ismember(varsMostrar, varsExistentes));

if isempty(varsValidas)
    disp(T);
else
    disp(T(:, varsValidas));
end

end