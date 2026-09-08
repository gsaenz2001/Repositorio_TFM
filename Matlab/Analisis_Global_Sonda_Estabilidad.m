function Analisis_Global_Sonda_Estabilidad()

clc; close all;
format compact;
format short g;

%% =========================================================
%  ANALISIS GLOBAL CON ARCHIVOS CAMBIOS_SONDA
%
%  Usa solo los archivos *_sonda.
%
%  De cada archivo:
%    - Bloques SIN_SONDA      -> estabilidad
%    - Bloques SONDA_P1..P4   -> deteccion de cambios
%
%  Objetivo:
%    Encontrar la mejor configuracion:
%       PCB + ventana + etapas
%
%    equilibrando:
%       1) estabilidad sin sonda
%       2) capacidad de detectar cambios con sonda
%
%  En las graficas:
%       X = estabilidad normalizada
%       Y = cambio con sonda normalizado
%
%  Cuanto mas arriba y a la derecha, mejor.
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
% Pesos del indice global
% ----------------------------------------------------------

pesoEstabilidad = 0.50;
pesoCambio      = 0.50;

% Dentro de CambioNorm:
% cambio directo = cuanto cambia la pista donde pongo la sonda
% selectividad   = cuanto mas cambia la pista directa que el resto
pesoCambioDirecto = 0.75;
pesoSelectividad  = 0.25;


% ----------------------------------------------------------
% Condiciones experimentales
% ----------------------------------------------------------

ventanasOrden = ["100ms", "10ms", "1ms", "100us"]; %#ok<NASGU>
etapasOrden   = [3, 5, 51, 101]; %#ok<NASGU>

% Condicion descartada tras el estudio inicial
condicionesDescartadas = [
    "100ms", "3"
];

numPistas = 4;


% ----------------------------------------------------------
% Limpieza de datos
% ----------------------------------------------------------

numMuestrasInicialesDescartar = 10;

usarFiltroRobusto = true;
Kmad = 8;

redondearModaSegunVentana = true;


% ----------------------------------------------------------
% Visualizacion
% ----------------------------------------------------------

topGlobalMostrar = 30;
mostrarRankingPorPCB = true;
mostrarGraficasPorPCB = true;
mostrarGraficaGlobal = true;

% ==========================================================


%% =========================================================
%  1. LEER ARCHIVOS DE SONDA
%% =========================================================

fprintf("\n============================================================\n");
fprintf("ANALISIS GLOBAL: ESTABILIDAD + CAMBIOS CON SONDA\n");
fprintf("Analisis: %s\n", char(nombreAnalisis));
fprintf("Carpeta: %s\n", char(carpeta));
fprintf("============================================================\n");

Datos = table();

for i = 1:numel(pcbsAnalisis)

    pcb = pcbsAnalisis(i);

    archivo = buscarArchivoSonda(carpeta, pcb);

    if archivo == ""
        warning("No se ha encontrado archivo de sonda para %s", char(pcb));
        continue;
    end

    fprintf("\nLeyendo: %s\n", char(archivo));

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

fprintf("\nMuestras totales leidas: %d\n", height(Datos));


%% =========================================================
%  2. FILTRAR CONDICIONES DESCARTADAS
%% =========================================================

Datos = filtrarCondicionesDescartadas(Datos, condicionesDescartadas);

fprintf("Muestras tras descartar condiciones: %d\n", height(Datos));


%% =========================================================
%  3. ESTABILIDAD DESDE BLOQUES SIN_SONDA
%% =========================================================

DatosSinSonda = Datos(Datos.EstadoSonda == "SIN_SONDA", :);

if isempty(DatosSinSonda)
    error("No hay bloques SIN_SONDA. No se puede calcular estabilidad.");
end

StatsEst = calcularEstabilidadSinSonda( ...
    DatosSinSonda, ...
    numPistas, ...
    numMuestrasInicialesDescartar, ...
    usarFiltroRobusto, ...
    Kmad);

ResumenEst = resumirEstabilidadPorConfiguracion(StatsEst);

fprintf("\n============================================================\n");
fprintf("RESUMEN DE ESTABILIDAD DESDE SIN_SONDA\n");
fprintf("============================================================\n");

mostrarTablaSegura(ResumenEst, { ...
    'PCB', ...
    'Ventana', ...
    'Etapas', ...
    'CVRobustoMedio_pct', ...
    'CVRobustoPeorPista_pct', ...
    'PistaMasEstable'});


%% =========================================================
%  4. CAMBIOS CON SONDA USANDO MODA
%% =========================================================

StatsModa = calcularModaPorBloque( ...
    Datos, ...
    numPistas, ...
    numMuestrasInicialesDescartar, ...
    usarFiltroRobusto, ...
    Kmad, ...
    redondearModaSegunVentana);

Cambios = calcularCambiosModa(StatsModa);

ResumenSonda = resumirPorEstadoSonda(Cambios);

ResumenCambios = resumirCambiosPorConfiguracion(ResumenSonda);

fprintf("\n============================================================\n");
fprintf("RESUMEN DE CAMBIOS CON SONDA\n");
fprintf("============================================================\n");

mostrarTablaSegura(ResumenCambios, { ...
    'PCB', ...
    'Ventana', ...
    'Etapas', ...
    'CambioDirectoMedioAbs_pct', ...
    'CambioOtrasMedioAbs_pct', ...
    'CambioAdyacenteMedioAbs_pct', ...
    'SelectividadMedia', ...
    'PistaMasSensible', ...
    'MejorEstadoSonda'});


%% =========================================================
%  5. UNIR ESTABILIDAD + CAMBIOS
%% =========================================================

Global = innerjoin(ResumenEst, ResumenCambios, ...
    'Keys', {'PCB', 'Ventana', 'Etapas'});

if isempty(Global)
    error("No coinciden las claves PCB + Ventana + Etapas entre estabilidad y cambios.");
end


%% =========================================================
%  6. NORMALIZACION E INDICE GLOBAL
%% =========================================================

% Estabilidad:
% menor CV robusto = mejor
Global.EstabilidadNorm = normalizarMenorMejor(Global.CVRobustoMedio_pct);

% Cambio:
% mayor cambio directo = mejor
% mayor selectividad = mejor
Global.CambioDirectoNorm = normalizarMayorMejor(Global.CambioDirectoMedioAbs_pct);
Global.SelectividadNorm  = normalizarMayorMejor(Global.SelectividadMedia);

Global.CambioNorm = ...
    pesoCambioDirecto * Global.CambioDirectoNorm + ...
    pesoSelectividad  * Global.SelectividadNorm;

Global.IndiceGlobal = ...
    pesoEstabilidad * Global.EstabilidadNorm + ...
    pesoCambio      * Global.CambioNorm;

Global = sortrows(Global, "IndiceGlobal", "descend");


%% =========================================================
%  7. RANKING GLOBAL
%% =========================================================

fprintf("\n============================================================\n");
fprintf("RANKING GLOBAL: ESTABILIDAD + CAMBIO CON SONDA\n");
fprintf("IndiceGlobal = %.2f*EstabilidadNorm + %.2f*CambioNorm\n", pesoEstabilidad, pesoCambio);
fprintf("CambioNorm = %.2f*CambioDirectoNorm + %.2f*SelectividadNorm\n", pesoCambioDirecto, pesoSelectividad);
fprintf("============================================================\n");

varsGlobal = { ...
    'PCB', ...
    'Ventana', ...
    'Etapas', ...
    'EstabilidadNorm', ...
    'CambioNorm', ...
    'IndiceGlobal', ...
    'CVRobustoMedio_pct', ...
    'CambioDirectoMedioAbs_pct', ...
    'SelectividadMedia', ...
    'PistaMasSensible'};

nTop = min(topGlobalMostrar, height(Global));

mostrarTablaSegura(Global(1:nTop,:), varsGlobal);


%% =========================================================
%  8. MEJOR CONFIGURACION POR PCB
%% =========================================================

MejorPorPCB = seleccionarMejorPorPCB(Global);

fprintf("\n============================================================\n");
fprintf("MEJOR CONFIGURACION POR PCB\n");
fprintf("============================================================\n");

mostrarTablaSegura(MejorPorPCB, varsGlobal);


%% =========================================================
%  9. RESUMEN FINAL DE GANADORES
%% =========================================================

imprimirResumenGanadores(Global, pesoEstabilidad, pesoCambio);


%% =========================================================
%  10. RANKING DETALLADO POR PCB
%% =========================================================

if mostrarRankingPorPCB

    fprintf("\n============================================================\n");
    fprintf("RANKING DETALLADO POR PCB\n");
    fprintf("============================================================\n");

    pcbs = unique(Global.PCB, 'stable');

    for i = 1:numel(pcbs)

        pcb = pcbs(i);

        Tpcb = Global(Global.PCB == pcb, :);
        Tpcb = sortrows(Tpcb, "IndiceGlobal", "descend");

        fprintf("\n------------------------------------------------------------\n");
        fprintf("PCB: %s\n", char(pcb));
        fprintf("------------------------------------------------------------\n");

        mostrarTablaSegura(Tpcb, varsGlobal);

    end

end


%% =========================================================
%  11. GRAFICAS DE PUNTOS
%% =========================================================

if mostrarGraficasPorPCB
    graficarPorPCB(Global);
end

if mostrarGraficaGlobal
    graficarGlobal(Global, MejorPorPCB);
end

fprintf("\nProceso completado.\n");
fprintf("Este analisis usa solo los archivos de CAMBIOS_SONDA.\n");
fprintf("La estabilidad se calcula desde los bloques SIN_SONDA de esos mismos archivos.\n");

end


%% ========================================================================
%  FUNCIONES AUXILIARES
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


function StatsEst = calcularEstabilidadSinSonda(DatosSinSonda, numPistas, nDescartar, usarFiltro, Kmad)

comb = unique(DatosSinSonda(:, {'PCB', 'Ventana', 'Etapas'}));

StatsEst = table();

for i = 1:height(comb)

    idxBloque = ...
        DatosSinSonda.PCB == comb.PCB(i) & ...
        DatosSinSonda.Ventana == comb.Ventana(i) & ...
        DatosSinSonda.Etapas == comb.Etapas(i);

    Tbloque = DatosSinSonda(idxBloque,:);

    for p = 1:numPistas

        nombreFreq = "Freq" + string(p);
        x = Tbloque.(nombreFreq);

        x = limpiarFrecuencias(x, nDescartar, usarFiltro, Kmad);

        if isempty(x)
            medianaHz = NaN;
            madHz = NaN;
            cvPct = NaN;
            nValidas = 0;
        else
            medianaHz = median(x, 'omitnan');
            madHz = median(abs(x - medianaHz), 'omitnan');
            cvPct = 100 * madHz / medianaHz;
            nValidas = numel(x);
        end

        fila = table( ...
            comb.PCB(i), ...
            comb.Ventana(i), ...
            comb.Etapas(i), ...
            p, ...
            "P" + string(p), ...
            medianaHz, ...
            madHz, ...
            cvPct, ...
            nValidas, ...
            'VariableNames', { ...
                'PCB', ...
                'Ventana', ...
                'Etapas', ...
                'Pista', ...
                'NombrePista', ...
                'Mediana_Hz', ...
                'MAD_Hz', ...
                'CVRobusto_pct', ...
                'NumMuestrasValidas'});

        StatsEst = [StatsEst; fila]; %#ok<AGROW>

    end

end

end


function ResumenEst = resumirEstabilidadPorConfiguracion(StatsEst)

comb = unique(StatsEst(:, {'PCB', 'Ventana', 'Etapas'}));

ResumenEst = table();

for i = 1:height(comb)

    idx = ...
        StatsEst.PCB == comb.PCB(i) & ...
        StatsEst.Ventana == comb.Ventana(i) & ...
        StatsEst.Etapas == comb.Etapas(i);

    T = StatsEst(idx,:);

    cvMedio = mean(T.CVRobusto_pct, 'omitnan');
    cvMediana = median(T.CVRobusto_pct, 'omitnan');
    cvPeor = max(T.CVRobusto_pct, [], 'omitnan');

    [~, idxMejor] = min(T.CVRobusto_pct);
    pistaMasEstable = T.NombrePista(idxMejor);

    fila = table( ...
        comb.PCB(i), ...
        comb.Ventana(i), ...
        comb.Etapas(i), ...
        cvMedio, ...
        cvMediana, ...
        cvPeor, ...
        pistaMasEstable, ...
        'VariableNames', { ...
            'PCB', ...
            'Ventana', ...
            'Etapas', ...
            'CVRobustoMedio_pct', ...
            'CVRobustoMediana_pct', ...
            'CVRobustoPeorPista_pct', ...
            'PistaMasEstable'});

    ResumenEst = [ResumenEst; fila]; %#ok<AGROW>

end

end


function StatsModa = calcularModaPorBloque(Datos, numPistas, nDescartar, usarFiltro, Kmad, redondearSegunVentana)

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

        x = limpiarFrecuencias(x, nDescartar, usarFiltro, Kmad);

        resolucionHz = resolucionVentanaHz(comb.Ventana(i));

        if redondearSegunVentana && ~isempty(x)
            xModa = round(x / resolucionHz) * resolucionHz;
        else
            xModa = x;
        end

        if isempty(xModa)
            modaHz = NaN;
            porcentajeModa = NaN;
            nValidas = 0;
        else
            [modaHz, porcentajeModa] = modaRobusta(xModa);
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
            porcentajeModa, ...
            nValidas, ...
            resolucionHz, ...
            'VariableNames', { ...
                'PCB', ...
                'EstadoSonda', ...
                'Ventana', ...
                'Etapas', ...
                'Pista', ...
                'NombrePista', ...
                'Moda_Hz', ...
                'PorcentajeModa', ...
                'NumMuestrasValidas', ...
                'Resolucion_Hz'});

        StatsModa = [StatsModa; fila]; %#ok<AGROW>

    end

end

end


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

    esOtra = pistaMedida ~= sondaPista;

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
            'DeltaModa_Hz', ...
            'DeltaModaAbs_Hz', ...
            'DeltaModa_pct', ...
            'DeltaModaAbs_pct'});

    Cambios = [Cambios; fila]; %#ok<AGROW>

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
            'Selectividad', ...
            'PistaMasAfectada', ...
            'MaxCambioPistaAbs_pct'});

    ResumenSonda = [ResumenSonda; fila]; %#ok<AGROW>

end

end


function ResumenCambios = resumirCambiosPorConfiguracion(ResumenSonda)

comb = unique(ResumenSonda(:, {'PCB', 'Ventana', 'Etapas'}));

ResumenCambios = table();

for i = 1:height(comb)

    idx = ...
        ResumenSonda.PCB == comb.PCB(i) & ...
        ResumenSonda.Ventana == comb.Ventana(i) & ...
        ResumenSonda.Etapas == comb.Etapas(i);

    T = ResumenSonda(idx,:);

    cambioDirectoMedio = mean(T.CambioDirectoAbs_pct, 'omitnan');
    cambioOtrasMedio = mean(T.CambioOtrasAbs_pct, 'omitnan');
    cambioAdyMedio = mean(T.CambioAdyacenteAbs_pct, 'omitnan');

    selectividadMedia = cambioDirectoMedio / max(cambioOtrasMedio, eps);

    [~, idxMejor] = max(T.CambioDirectoAbs_pct);

    pistaMasSensible = "P" + string(T.SondaPista(idxMejor));
    mejorEstadoSonda = T.EstadoSonda(idxMejor);

    fila = table( ...
        comb.PCB(i), ...
        comb.Ventana(i), ...
        comb.Etapas(i), ...
        cambioDirectoMedio, ...
        cambioOtrasMedio, ...
        cambioAdyMedio, ...
        selectividadMedia, ...
        pistaMasSensible, ...
        mejorEstadoSonda, ...
        'VariableNames', { ...
            'PCB', ...
            'Ventana', ...
            'Etapas', ...
            'CambioDirectoMedioAbs_pct', ...
            'CambioOtrasMedioAbs_pct', ...
            'CambioAdyacenteMedioAbs_pct', ...
            'SelectividadMedia', ...
            'PistaMasSensible', ...
            'MejorEstadoSonda'});

    ResumenCambios = [ResumenCambios; fila]; %#ok<AGROW>

end

end


function x = limpiarFrecuencias(x, nDescartar, usarFiltro, Kmad)

x = x(:);
x = x(~isnan(x));
x = x(x > 0);

if numel(x) > nDescartar
    x = x(nDescartar+1:end);
end

if isempty(x)
    return;
end

if usarFiltro && numel(x) > 20

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


function y = normalizarMayorMejor(x)

y = NaN(size(x));

idx = ~isnan(x);

if ~any(idx)
    return;
end

xmin = min(x(idx));
xmax = max(x(idx));

if xmax == xmin
    y(idx) = 100;
else
    y(idx) = 100 * (x(idx) - xmin) / (xmax - xmin);
end

end


function y = normalizarMenorMejor(x)

y = NaN(size(x));

idx = ~isnan(x);

if ~any(idx)
    return;
end

xmin = min(x(idx));
xmax = max(x(idx));

if xmax == xmin
    y(idx) = 100;
else
    y(idx) = 100 * (xmax - x(idx)) / (xmax - xmin);
end

end


function MejorPorPCB = seleccionarMejorPorPCB(Global)

pcbs = unique(Global.PCB, 'stable');

MejorPorPCB = table();

for i = 1:numel(pcbs)

    pcb = pcbs(i);

    T = Global(Global.PCB == pcb, :);
    T = sortrows(T, "IndiceGlobal", "descend");

    MejorPorPCB = [MejorPorPCB; T(1,:)]; %#ok<AGROW>

end

MejorPorPCB = sortrows(MejorPorPCB, "IndiceGlobal", "descend");

end


function imprimirResumenGanadores(Global, pesoEstabilidad, pesoCambio)

fprintf("\n============================================================\n");
fprintf("RESUMEN FINAL DE MEJORES CONFIGURACIONES\n");
fprintf("============================================================\n");

% Mejor estabilidad
[~, idxEst] = max(Global.EstabilidadNorm);
mejorEst = Global(idxEst,:);

% Mejor cambio con sonda
[~, idxCamb] = max(Global.CambioNorm);
mejorCamb = Global(idxCamb,:);

% Mejor compromiso global
[~, idxGlob] = max(Global.IndiceGlobal);
mejorGlob = Global(idxGlob,:);

fprintf("\nMEJOR CONFIGURACION POR ESTABILIDAD:\n");
fprintf("  PCB: %s\n", char(mejorEst.PCB));
fprintf("  Ventana: %s\n", char(mejorEst.Ventana));
fprintf("  Etapas: %d\n", mejorEst.Etapas);
fprintf("  CV robusto medio: %.6g %%\n", mejorEst.CVRobustoMedio_pct);
fprintf("  Estabilidad normalizada: %.2f / 100\n", mejorEst.EstabilidadNorm);

fprintf("\nMEJOR CONFIGURACION POR DETECCION DE CAMBIO CON SONDA:\n");
fprintf("  PCB: %s\n", char(mejorCamb.PCB));
fprintf("  Ventana: %s\n", char(mejorCamb.Ventana));
fprintf("  Etapas: %d\n", mejorCamb.Etapas);
fprintf("  Cambio directo medio: %.6g %%\n", mejorCamb.CambioDirectoMedioAbs_pct);
fprintf("  Selectividad media: %.6g\n", mejorCamb.SelectividadMedia);
fprintf("  Cambio normalizado: %.2f / 100\n", mejorCamb.CambioNorm);
fprintf("  Pista mas sensible: %s\n", char(mejorCamb.PistaMasSensible));
fprintf("  Mejor estado de sonda: %s\n", char(mejorCamb.MejorEstadoSonda));

fprintf("\nMEJOR COMPROMISO GLOBAL ESTABILIDAD + CAMBIO:\n");
fprintf("  PCB: %s\n", char(mejorGlob.PCB));
fprintf("  Ventana: %s\n", char(mejorGlob.Ventana));
fprintf("  Etapas: %d\n", mejorGlob.Etapas);
fprintf("  Estabilidad normalizada: %.2f / 100\n", mejorGlob.EstabilidadNorm);
fprintf("  Cambio normalizado: %.2f / 100\n", mejorGlob.CambioNorm);
fprintf("  Indice global: %.2f / 100\n", mejorGlob.IndiceGlobal);
fprintf("  CV robusto medio: %.6g %%\n", mejorGlob.CVRobustoMedio_pct);
fprintf("  Cambio directo medio: %.6g %%\n", mejorGlob.CambioDirectoMedioAbs_pct);
fprintf("  Selectividad media: %.6g\n", mejorGlob.SelectividadMedia);
fprintf("  Pesos usados: %.2f estabilidad + %.2f cambio\n", pesoEstabilidad, pesoCambio);

fprintf("\nINTERPRETACION:\n");
fprintf("  - La mejor por estabilidad es la que presenta menor dispersion sin sonda.\n");
fprintf("  - La mejor por cambio es la que detecta mejor la presencia de la sonda.\n");
fprintf("  - La mejor global es el compromiso entre ambas.\n");

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


function graficarPorPCB(Global)

pcbs = unique(Global.PCB, 'stable');

for i = 1:numel(pcbs)

    pcb = pcbs(i);
    T = Global(Global.PCB == pcb, :);

    if isempty(T)
        continue;
    end

    figure;
    hold on;
    grid on;

    etapasUnicas = unique(T.Etapas);
    colores = lines(numel(etapasUnicas));

    for e = 1:numel(etapasUnicas)

        etapa = etapasUnicas(e);
        Te = T(T.Etapas == etapa, :);

        scatter( ...
            Te.EstabilidadNorm, ...
            Te.CambioNorm, ...
            75, ...
            colores(e,:), ...
            'filled', ...
            'DisplayName', string(etapa) + " etapas");

    end

    % Mejor configuracion de esta PCB
    Tordenado = sortrows(T, "IndiceGlobal", "descend");
    mejor = Tordenado(1,:);

    scatter( ...
        mejor.EstabilidadNorm, ...
        mejor.CambioNorm, ...
        180, ...
        'p', ...
        'filled', ...
        'MarkerEdgeColor', 'k', ...
        'DisplayName', 'Mejor compromiso');

    etiqueta = mejor.Ventana + " - " + string(mejor.Etapas) + " etapas";

    text( ...
        mejor.EstabilidadNorm, ...
        mejor.CambioNorm, ...
        "  " + etiqueta, ...
        'Interpreter', 'none', ...
        'FontSize', 10, ...
        'FontWeight', 'bold');

    xlabel("Estabilidad normalizada [0-100]");
    ylabel("Cambio con sonda normalizado [0-100]");
    title("Compromiso estabilidad-cambio: " + pcb, 'Interpreter', 'none');

    legend('Location','best');

    xlim([0 105]);
    ylim([0 105]);

    % Cuanto mas arriba y a la derecha, mejor.
    % Derecha = mayor estabilidad.
    % Arriba  = mayor deteccion de cambio con sonda.

end

end


function graficarGlobal(Global, MejorPorPCB)

figure;
hold on;
grid on;

pcbs = unique(Global.PCB, 'stable');
colores = lines(numel(pcbs));

for i = 1:numel(pcbs)

    pcb = pcbs(i);
    T = Global(Global.PCB == pcb, :);

    scatter( ...
        T.EstabilidadNorm, ...
        T.CambioNorm, ...
        65, ...
        colores(i,:), ...
        'filled', ...
        'DisplayName', pcb);

end

% Marcar mejor de cada PCB
for i = 1:height(MejorPorPCB)

    scatter( ...
        MejorPorPCB.EstabilidadNorm(i), ...
        MejorPorPCB.CambioNorm(i), ...
        130, ...
        'd', ...
        'MarkerEdgeColor', 'k', ...
        'LineWidth', 1.5, ...
        'HandleVisibility', 'off');

    etiqueta = MejorPorPCB.PCB(i) + " | " + ...
               MejorPorPCB.Ventana(i) + "-" + ...
               string(MejorPorPCB.Etapas(i));

    text( ...
        MejorPorPCB.EstabilidadNorm(i), ...
        MejorPorPCB.CambioNorm(i), ...
        "  " + etiqueta, ...
        'Interpreter', 'none', ...
        'FontSize', 8, ...
        'FontWeight', 'bold');

end

% Marcar mejor global
[~, idxBest] = max(Global.IndiceGlobal);
best = Global(idxBest,:);

scatter( ...
    best.EstabilidadNorm, ...
    best.CambioNorm, ...
    260, ...
    'p', ...
    'filled', ...
    'MarkerEdgeColor', 'k', ...
    'LineWidth', 1.8, ...
    'DisplayName', 'Mejor global');

xlabel("Estabilidad normalizada [0-100]");
ylabel("Cambio con sonda normalizado [0-100]");
title("Comparacion global estabilidad-cambio con sonda", 'Interpreter', 'none');

legend('Location','bestoutside');

xlim([0 105]);
ylim([0 105]);

% Cuanto mas arriba y a la derecha, mejor.

end