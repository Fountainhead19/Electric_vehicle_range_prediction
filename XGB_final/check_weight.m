
smallFolder = 'D:/vehicle_range_nn/logs/logs_handler'; % Папка с меньшим числом файлов
largeFolder = 'D:/vehicle_range_nn/logs/logs_all_find'; % Папка с большим числом файлов

% Получаем список всех .mat файлов в обеих папках
smallFiles = dir(fullfile(smallFolder, '*.mat'));
largeFiles = dir(fullfile(largeFolder, '*.mat'));

% Инициализируем переменные для хранения общих весов
totalWeightSmall = 0;
totalWeightLarge = 0;

% Проходим по файлам из меньшей папки
for i = 1:length(smallFiles)
    smallFileName = smallFiles(i).name;
    
    % Ищем файл с таким же именем в большой папке
    matchIndex = find(strcmp({largeFiles.name}, smallFileName), 1);
    
    if ~isempty(matchIndex)
        
        largeFileWeight = largeFiles(matchIndex).bytes;
        totalWeightSmall = totalWeightSmall + largeFileWeight; % Суммируем вес совпавших файлов
    end
end

% Вычисляем общий вес всех файлов в большей папке
for i = 1:length(largeFiles)
    totalWeightLarge = totalWeightLarge + largeFiles(i).bytes;
end
% Переводим байты в гигабайты
totalWeightSmallGB = totalWeightSmall / (1024^3);
totalWeightLargeGB = totalWeightLarge / (1024^3);

% Сравниваем общий вес файлов
disp(['Вес совпадающих файлов: ', num2str(totalWeightSmallGB), ' гб']);
disp(['Общий вес всех файлов в большей папке: ', num2str(totalWeightLargeGB), ' гб']);