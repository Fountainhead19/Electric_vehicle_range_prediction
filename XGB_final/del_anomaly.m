% Указываем путь к папке с новыми мат-файлами
folder_path = 'D:/vehicle_range_nn/logs/logs_handler_final';

% Получаем список всех mat-файлов в папке
files = dir(fullfile(folder_path, '*.mat'));

% Цикл по каждому файлу
for i = 1:length(files)
    % Загрузим данные из текущего mat-файла
    mat_data = load(fullfile(folder_path, files(i).name));
    
    % Предположим, что данные находятся в переменной 'reduced_data'
    reduced_data = mat_data.reduced_data;

    % Удаляем строки, где vehicle_range равно 0
    reduced_data = reduced_data(reduced_data.vehicle_range > 0.01, :);
    
    % Проверяем, остались ли строки после удаления
    if isempty(reduced_data)
        % Если файл теперь пустой, удаляем его
        delete(fullfile(folder_path, files(i).name));
    else
        % Если строки остались, пересохраняем файл, заменяя старый
        save(fullfile(folder_path, files(i).name), 'reduced_data');
    end
end