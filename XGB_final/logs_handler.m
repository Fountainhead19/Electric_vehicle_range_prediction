%dt = gradient(seconds(All_Data_TT.Time));
%r = 0.472;
%u = 22.823;
%v = (v1 + v2)/2;
%v = v * (pi*r)/(u*30);
%S = S0 + v * dt;
% Путь к папке с файлами
folderPath = 'D:/vehicle_range_nn/logs/test_logs';  % путь к исходной папке

% Путь к папке для сохранения результатов
saveFolderPath = 'D:/vehicle_range_nn/logs/test_logs/test_handler';  %  папка для сохранения

% Получаем список всех .mat файлов в папке
matFiles = dir(fullfile(folderPath, '*.mat'));

% Постоянные значения
radius = 0.472;  % радиус (в метрах)
gear_ratio = 22.823 * 30;
broke_files = 0;
files_width_14 = 189;
% Обрабатываем каждый файл
for k = 1:length(matFiles)
    % Загрузка мат файла
    matFilePath = fullfile(folderPath, matFiles(k).name);
    data = load(matFilePath);
    
    try
        timetableData = data.Extract_signals_all_files_discrete;  
    catch
        broke_files = broke_files + 1;
        continue;
    end

    % Проверка количества столбцов
    if width(timetableData) < 14
        continue; % Пропустить, если столбцов меньше 15
    end
    files_width_14 = files_width_14 + 1;
    % Удаление строк с NaN
    timetableData = rmmissing(timetableData);
    
    % Вычисление V(n) и dt
    V = ((timetableData.L_INV2TM_MotorSpeed + timetableData.R_INV2TM_MotorSpeed) / 2) * (pi * radius / gear_ratio);
    dt = gradient(seconds(timetableData.Time));  % Время в секундах
    
    % Инициализация столбца S
    S = zeros(height(timetableData), 1);  % Начальный столбец для S
    
    % Вычисляем значения для S(n)
    for n = 2:height(timetableData)
        S(n) = S(n-1) + V(n) * dt(n);
    end
    
    % Перевод S из метров в километры
    S = S / 1000;
    
    % Добавление нового столбца S в timetable
    timetableData.S = S;
    
    % Сохранение изменений в другую папку, с таким же именем файла
    saveFilePath = fullfile(saveFolderPath, matFiles(k).name);
    save(saveFilePath, 'timetableData');
end