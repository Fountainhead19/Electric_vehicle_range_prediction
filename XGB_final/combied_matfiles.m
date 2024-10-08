% Указываем путь к папке с мат-файлами
folder_path = 'D:/vehicle_range_nn/logs/test_logs/test_handler_final';

% Имя для итогового файла
output_file = fullfile(folder_path, 'combined_data.mat');

% Получаем список всех mat-файлов в папке
files = dir(fullfile(folder_path, '*.mat'));

% Инициализируем переменную для объединенных данных
combined_data = [];

% Цикл по каждому файлу
for i = 1:length(files)
    % Загружаем данные из текущего mat-файла
    mat_data = load(fullfile(folder_path, files(i).name));
    
    % Предположим, что данные находятся в переменной 'reduced_data'
    reduced_data = mat_data.reduced_data;
    
    % Проверяем наличие столбца 'Yaw_Rate' и удаляем его, если он есть
    if ismember('Yaw_Rate', reduced_data.Properties.VariableNames)
        reduced_data = removevars(reduced_data, 'Yaw_Rate');
    end
    
    if ismember('SteeringWheelAngle', reduced_data.Properties.VariableNames)
        reduced_data = removevars(reduced_data, 'SteeringWheelAngle');
    end
    if ismember('S', reduced_data.Properties.VariableNames)
        reduced_data = removevars(reduced_data, 'S');
    end
    % Объединяем данные по строкам
    if isempty(combined_data)
        combined_data = reduced_data;  % Если это первый файл, инициализируем combined_data
    else
        combined_data = [combined_data; reduced_data];  % Добавляем строки
    end
end

% Сохраняем объединенные данные в один mat-файл
save(output_file, 'combined_data');
Table = timetable2table(combined_data);
Table = removevars(Table,'Time');
Table = table2array(Table);
save('D:/vehicle_range_nn/logs/test_logs/test_handler_final/pythonData.mat', 'Table');