function Estabilidad_PCB_PorGrupos_Y_Global()

clc; close all;
format compact;
format short g;

%% =========================================================
%  ESTABILIDAD PCB - TABLAS POR GRUPO Y TABLA GLOBAL
%
%  Para cada grupo:
%     - Tabla de condiciones
%     - Tabla final simple
%
%  Para el analisis completo:
%     - Tabla de condiciones global
%     - Tabla final simple global
%
%% =========================================================


%% ===================== CONFIGURACION =====================

carpeta = "D:\TFM\PYTHON\ESTABILIDAD";

% ==========================================================
% CAMBIA SOLO ESTO
% ==========================================================

% ---- M1 ----
% nombreAnalisis = "M1";
% gruposAnalisis = ["M1_1L", "M1_2L"];

% ---- M2 ----
% nombreAnalisis = "M2_2L";
% gruposAnalisis = ["M2_2L"];

% ---- M3 ----
% nombreAnalisis = "M3";
% gruposAnalisis = ["M3_1L", "M3_2L"];

% ---- M4 ----
% nombreAnalisis = "M4";
% gruposAnalisis = ["M4_1L", "M4_2L"];

% ---- M5 ----
nombreAnalisis = "M5_2L";
gruposAnalisis = ["M5_2L"];

% ==========================================================

ventanasOrden = ["100ms", "10ms", "1ms", "100us"];
etapasOrden   = [3, 5, 51, 101];

numPistas = 4;

% "moda" o "mediana"
metodoCentro = "moda";


%% =========================================================
%  ANALISIS
%% =========================================================

fprintf("\n============================================================\n");
fprintf("ANALISIS: %s\n", nombreAnalisis);
fprintf("============================================================\n");

ResultadosGlobal = table();

for g = 1:numel(gruposAnalisis)

    grupo = gruposAnalisis(g);

    fprintf("\n\n############################################################\n");
    fprintf("GRUPO: %s\n", grupo);
    fprintf("############################################################\n");

    %% =====================================================
    %  1. LOCALIZAR ARCHIVOS DEL GRUPO
    %% =====================================================

    patron = grupo + "_*.txt";
    archivos = dir(fullfile(carpeta, patron));

    if isempty(archivos)
        warning("No se han encontrado archivos para el grupo %s", grupo);
        continue;
    end

    [~, orden] = sort({archivos.name});
    archivos = archivos(orden);

    fprintf("\nArchivos encontrados para %s: %d\n", grupo, numel(archivos));

    for i = 1:numel(archivos)
        fprintf("  %s\n", archivos(i).name);
    end


    %% =====================================================
    %  2. LEER ARCHIVOS Y CALCULAR DISPERSION
    %% =====================================================

    ResultadosGrupo = table();

    fprintf("\nLeyendo archivos de %s...\n", grupo);

    for a = 1:numel(archivos)

        archivoCompleto = fullfile(archivos(a).folder, archivos(a).name);
        [~, pcb, ~] = fileparts(archivoCompleto);

        fprintf("  Leyendo %s\n", archivos(a).name);

        Datos = leerArchivoEstabilidad(archivoCompleto);

        for v = 1:numel(ventanasOrden)

            ventana = ventanasOrden(v);

            for e = 1:numel(etapasOrden)

                etapas = etapasOrden(e);

                idxCond = Datos.Ventana == ventana & Datos.Etapas == etapas;
                Tconf = Datos(idxCond, :);

                dispPistasPct = NaN(1, numPistas);

                for p = 1:numPistas

                    nombrePista = "Freq" + string(p);

                    x = Tconf.(nombrePista);
                    x = x(~isnan(x));
                    x = x(x > 0);

                    if isempty(x)
                        continue;
                    end

                    centroHz = calcularCentro(x, metodoCentro);

                    if isnan(centroHz) || centroHz <= 0
                        continue;
                    end

                    desviacionMediaHz = mean(abs(x - centroHz), 'omitnan');
                    dispPistasPct(p) = desviacionMediaHz / centroHz * 100;
                end

                dispersionMedia4PistasPct = mean(dispPistasPct, 'omitnan');

                fila = table( ...
                    string(grupo), ...
                    string(pcb), ...
                    ventana, ...
                    etapas, ...
                    dispPistasPct(1), ...
                    dispPistasPct(2), ...
                    dispPistasPct(3), ...
                    dispPistasPct(4), ...
                    dispersionMedia4PistasPct, ...
                    'VariableNames', { ...
                        'Grupo', ...
                        'PCB', ...
                        'Ventana', ...
                        'Etapas', ...
                        'Disp_P1_pct', ...
                        'Disp_P2_pct', ...
                        'Disp_P3_pct', ...
                        'Disp_P4_pct', ...
                        'Disp_media_4pistas_pct'});

                ResultadosGrupo = [ResultadosGrupo; fila]; %#ok<AGROW>
            end
        end
    end

    ResultadosGlobal = [ResultadosGlobal; ResultadosGrupo]; %#ok<AGROW>


    %% =====================================================
    %  3. TABLA DE CONDICIONES DEL GRUPO
    %% =====================================================

    TablaCondicionesGrupo = crearTablaCondiciones( ...
        ResultadosGrupo, ...
        ventanasOrden, ...
        etapasOrden);

    disp(" ");
    disp("============================================================");
    disp("TABLA DE CONDICIONES - " + grupo);
    disp("Valor = dispersion media de las 4 pistas [%]");
    disp("Menor valor = PCB mas estable en esa condicion");
    disp("============================================================");
    disp(TablaCondicionesGrupo);


    %% =====================================================
    %  4. TABLA FINAL SIMPLE DEL GRUPO
    %% =====================================================

    TablaFinalGrupo = crearTablaFinalSimple(TablaCondicionesGrupo);

    disp(" ");
    disp("============================================================");
    disp("TABLA FINAL SIMPLE - " + grupo);
    disp("Ordenada por Estabilidad_media_0_100, de mayor a menor");
    disp("============================================================");
    disp(TablaFinalGrupo);

end


%% =========================================================
%  5. TABLAS GLOBALES DEL ANALISIS COMPLETO
%% =========================================================

if ~isempty(ResultadosGlobal)

    TablaCondicionesGlobal = crearTablaCondiciones( ...
        ResultadosGlobal, ...
        ventanasOrden, ...
        etapasOrden);

    TablaFinalGlobal = crearTablaFinalSimple(TablaCondicionesGlobal);

    disp(" ");
    disp("############################################################");
    disp("COMPARACION GLOBAL DEL ANALISIS COMPLETO - " + nombreAnalisis);
    disp("############################################################");

    disp(" ");
    disp("============================================================");
    disp("TABLA DE CONDICIONES GLOBAL - " + nombreAnalisis);
    disp("Valor = dispersion media de las 4 pistas [%]");
    disp("Menor valor = PCB mas estable en esa condicion");
    disp("============================================================");
    disp(TablaCondicionesGlobal);

    disp(" ");
    disp("============================================================");
    disp("TABLA FINAL SIMPLE GLOBAL - " + nombreAnalisis);
    disp("Compara todas las PCBs de todos los grupos seleccionados");
    disp("Ordenada por Estabilidad_media_0_100, de mayor a menor");
    disp("============================================================");
    disp(TablaFinalGlobal);
end


%% =========================================================
%  FIN
%% =========================================================

disp(" ");
disp("============================================================");
disp("ANALISIS TERMINADO");
disp("Se han mostrado tablas por grupo y tabla global.");
disp("Solo se ha usado Command Window.");
disp("============================================================");

end


%% =========================================================
%  FUNCIONES
%% =========================================================

function centro = calcularCentro(x, metodoCentro)

    metodoCentro = lower(string(metodoCentro));

    switch metodoCentro

        case "moda"
            centro = mode(x);

        case "mediana"
            centro = median(x, 'omitnan');

        otherwise
            error("Metodo no reconocido. Usa 'moda' o 'mediana'.");
    end
end


function T = leerArchivoEstabilidad(archivo)

    texto = fileread(archivo);
    lineas = splitlines(string(texto));

    ventanaActual = "";
    etapasActual = NaN;

    Ventana = strings(0,1);
    Etapas  = [];
    Idx     = [];
    Freq1   = [];
    Freq2   = [];
    Freq3   = [];
    Freq4   = [];

    for i = 1:numel(lineas)

        linea = strtrim(lineas(i));

        if linea == ""
            continue;
        end

        if startsWith(linea, "# VENTANA:")
            ventanaActual = strtrim(extractAfter(linea, ":"));
            ventanaActual = replace(ventanaActual, " ", "");
            continue;
        end

        if startsWith(linea, "# ETAPAS_PRINCIPAL:")
            etapasActual = str2double(strtrim(extractAfter(linea, ":")));
            continue;
        end

        if startsWith(linea, "#") || ...
           startsWith(lower(linea), "idx") || ...
           startsWith(linea, "=")
            continue;
        end

        nums = sscanf(char(linea), "%f");

        if numel(nums) ~= 5
            continue;
        end

        Ventana(end+1,1) = ventanaActual; %#ok<AGROW>
        Etapas(end+1,1)  = etapasActual;  %#ok<AGROW>
        Idx(end+1,1)     = nums(1);       %#ok<AGROW>
        Freq1(end+1,1)   = nums(2);       %#ok<AGROW>
        Freq2(end+1,1)   = nums(3);       %#ok<AGROW>
        Freq3(end+1,1)   = nums(4);       %#ok<AGROW>
        Freq4(end+1,1)   = nums(5);       %#ok<AGROW>
    end

    T = table(Ventana, Etapas, Idx, Freq1, Freq2, Freq3, Freq4);
end


function TablaFinal = crearTablaCondiciones(Resultados, ventanasOrden, etapasOrden)

    pcbs = unique(Resultados.PCB, "stable");

    Ventana = strings(0,1);
    Etapas = [];

    for v = 1:numel(ventanasOrden)
        for e = 1:numel(etapasOrden)

            Ventana(end+1,1) = ventanasOrden(v); %#ok<AGROW>
            Etapas(end+1,1)  = etapasOrden(e);    %#ok<AGROW>
        end
    end

    TablaFinal = table(Ventana, Etapas);

    for p = 1:numel(pcbs)

        pcb = pcbs(p);
        valores = NaN(numel(Ventana), 1);

        for i = 1:numel(Ventana)

            idx = Resultados.PCB == pcb & ...
                  Resultados.Ventana == Ventana(i) & ...
                  Resultados.Etapas == Etapas(i);

            if any(idx)
                valores(i) = Resultados.Disp_media_4pistas_pct(idx);
            end
        end

        nombreColumna = matlab.lang.makeValidName(char(pcb));
        TablaFinal.(nombreColumna) = valores;
    end
end


function TablaFinal = crearTablaFinalSimple(TablaCondiciones)

    nombresColumnas = string(TablaCondiciones.Properties.VariableNames);
    columnasPCB = nombresColumnas(3:end);

    X = double(TablaCondiciones{:, 3:end});

    nCond = size(X, 1);
    nPCB  = size(X, 2);

    Ratio = NaN(size(X));
    Estabilidad = NaN(size(X));

    for r = 1:nCond

        fila = X(r, :);
        validos = ~isnan(fila) & fila > 0;

        if ~any(validos)
            continue;
        end

        mejorValor = min(fila(validos));

        Ratio(r, validos) = fila(validos) / mejorValor;
        Estabilidad(r, validos) = 100 ./ Ratio(r, validos);
    end

    PCB = columnasPCB(:);

    Dispersion_media_pct = NaN(nPCB, 1);
    Estabilidad_media_0_100 = NaN(nPCB, 1);

    for c = 1:nPCB

        xDisp = X(:, c);
        xDisp = xDisp(~isnan(xDisp));

        xEstab = Estabilidad(:, c);
        xEstab = xEstab(~isnan(xEstab));

        if ~isempty(xDisp)
            Dispersion_media_pct(c) = mean(xDisp);
        end

        if ~isempty(xEstab)
            Estabilidad_media_0_100(c) = mean(xEstab);
        end
    end

    TablaFinal = table( ...
        PCB, ...
        Dispersion_media_pct, ...
        Estabilidad_media_0_100);

    TablaFinal = sortrows( ...
        TablaFinal, ...
        "Estabilidad_media_0_100", ...
        "descend");

    Posicion = (1:height(TablaFinal))';

    TablaFinal = addvars( ...
        TablaFinal, ...
        Posicion, ...
        'Before', ...
        'PCB');
end