% Указываем путь к папке с mat-файлами и папку для сохранения новых файлов
input_folder = 'D:/vehicle_range_nn/logs/test_logs/test_handler';
output_folder = 'D:/vehicle_range_nn/logs/test_logs/test_handler_final';

% Получаем список всех mat-файлов в папке
files = dir(fullfile(input_folder, '*.mat'));

% Цикл по каждому файлу
for i = 1:length(files)
    % Загрузим данные из текущего mat-файла
    mat_data = load(fullfile(input_folder, files(i).name));
    
    % Предположим, что ваши данные находятся в timetable (например, timetableData)
    timetableData = mat_data.timetableData;  % Замените 'timetableData' на правильное имя переменной
    
    % Задаем важные переменные из timetable (переименованные)
    B2V_TotalI = timetableData.B2V_TotalI;
    S = timetableData.S;
    B2V_SOC = timetableData.B2V_SOC;
    L_INV2TM_MotorSpeed = timetableData.L_INV2TM_MotorSpeed;
    
    % Цикл для сегментации данных
    segment_counter = 1;
    current_data = timetableData;  % Копируем данные, чтобы их модифицировать
    while true
        % Находим индексы, где B2V_TotalI отрицательный и скорости равны 0 (зарядка)
        charge_indexes = find(current_data.B2V_TotalI < 0 & current_data.L_INV2TM_MotorSpeed == 0 & current_data.R_INV2TM_MotorSpeed == 0);
        
        % Если нет больше моментов зарядки, останавливаемся
        if isempty(charge_indexes)
            % Сохраняем оставшиеся данные (если они есть) как отдельный сегмент
            if ~isempty(current_data)
                % Снижаем частоту данных с 0.01 до 0.1 сек (берем каждую 10-ю строку)
                reduced_data = current_data(1:10:end, :);
                
                % Корректируем S, чтобы начальная S была равна 0
                S_shift = reduced_data.S(1);
                reduced_data.S = reduced_data.S - S_shift;
                
                % Рассчитываем пройденное расстояние и расход SOC
                delta_S = reduced_data.S(end) - reduced_data.S(1);  % Пройденное расстояние
                delta_SOC = reduced_data.B2V_SOC(1) - reduced_data.B2V_SOC(end);  % Изменение SOC (расход)
                
                % Рассчитываем средний расход SOC на километр
                if delta_S > 0 && delta_SOC > 0
                    average_SOC_per_km = delta_SOC / delta_S;  % Средний расход SOC на км
                
                    % Рассчитываем остаточный пробег по конечному значению B2V_SOC
                    final_B2V_SOC = reduced_data.B2V_SOC(end);  % Конечный SOC
                    remaining_distance = final_B2V_SOC / average_SOC_per_km;  % Остаточный пробег
                
                    % Создаем столбец таргета (vehicle_range)
                    vehicle_range = remaining_distance - (reduced_data.S(end) - reduced_data.S);  % Остаточный пробег для каждой строки
                else
                    % Если нет значимого изменения SOC или пройденного расстояния, ставим NaN или 0
                    vehicle_range = zeros(height(reduced_data), 1);  % Либо можете использовать NaN для указания недоступных значений
                end

                % Рассчитываем средние значения за 10 минут (скользящее окно)
                avg_B2V_SOC = movmean(reduced_data.B2V_SOC, [600 0]);  % Окно 10 минут (600 точек)
                avg_B2V_TotalI = movmean(reduced_data.B2V_TotalI, [600 0]);  % Окно 10 минут
                avg_L_INV2TM_MotorSpeed = movmean(reduced_data.L_INV2TM_MotorSpeed, [600 0]);  % Окно 10 минут

                % Добавляем средние значения и таргет в timetable
                reduced_data.avg_B2V_SOC = avg_B2V_SOC;
                reduced_data.avg_B2V_TotalI = avg_B2V_TotalI;
                reduced_data.avg_L_INV2TM_MotorSpeed = avg_L_INV2TM_MotorSpeed;
                reduced_data.vehicle_range = vehicle_range;

                % Имя для нового файла
                file_prefix = strrep(files(i).name, '.mat', ['_' num2str(segment_counter)]);
                
                % Сохраняем мат-файл для оставшихся данных
                save(fullfile(output_folder, [file_prefix '.mat']), 'reduced_data');
            end
            break;  % Остановка цикла
        end
        
        % Определяем сегмент зарядки
        first_charge_index = charge_indexes(1);  % Первый момент зарядки
        last_charge_index = charge_indexes(find(diff(charge_indexes) > 1, 1));  % Последний момент зарядки (непрерывный)
        if isempty(last_charge_index)
            last_charge_index = charge_indexes(end);  % Если все подряд, берем последний индекс
        end

        % Разделение данных: до сегмента зарядки и после
        data_before_charge = current_data(1:first_charge_index-1, :);  % Данные до зарядки
        data_after_charge = current_data(last_charge_index+1:end, :);  % Данные после зарядки

        % Сохраняем сегмент до момента зарядки, если он не пуст
        if ~isempty(data_before_charge)
            % Снижаем частоту данных с 0.01 до 0.1 сек (берем каждую 10-ю строку)
            reduced_data = data_before_charge(1:10:end, :);
            
            % Корректируем S, чтобы начальная S была равна 0
            S_shift = reduced_data.S(1);
            reduced_data.S = reduced_data.S - S_shift;

            % Рассчитываем остаточный пробег по конечному значению S и B2V_SOC
            final_S = reduced_data.S(end);
            final_B2V_SOC = reduced_data.B2V_SOC(end);
            average_SOC_usage = mean(diff(reduced_data.B2V_SOC)) / 10; % Средний расход за лог
            
            remaining_distance = final_B2V_SOC * average_SOC_usage;

            % Создаем столбец таргета (vehicle_range)
            vehicle_range = final_S - reduced_data.S;

            % Рассчитываем средние значения за 10 минут (скользящее окно)
            avg_B2V_SOC = movmean(reduced_data.B2V_SOC, [600 0]);  % Окно 10 минут (600 точек)
            avg_B2V_TotalI = movmean(reduced_data.B2V_TotalI, [600 0]);  % Окно 10 минут
            avg_L_INV2TM_MotorSpeed = movmean(reduced_data.L_INV2TM_MotorSpeed, [600 0]);  % Окно 10 минут

            % Добавляем средние значения и таргет в timetable
            reduced_data.avg_B2V_SOC = avg_B2V_SOC;
            reduced_data.avg_B2V_TotalI = avg_B2V_TotalI;
            reduced_data.avg_L_INV2TM_MotorSpeed = avg_L_INV2TM_MotorSpeed;
            reduced_data.vehicle_range = vehicle_range;

            % Имя для нового файла
            file_prefix = strrep(files(i).name, '.mat', ['_' num2str(segment_counter)]);

            % Сохраняем мат-файл для сегмента до зарядки
            save(fullfile(output_folder, [file_prefix '.mat']), 'reduced_data');
            
            % Увеличиваем счётчик сегментов
            segment_counter = segment_counter + 1;
        end
        
        % Теперь продолжаем работать с данными после зарядки
        current_data = data_after_charge;  % Переносим оставшиеся данные для дальнейшей обработки
    end
end
