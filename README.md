![Python 3.6](https://img.shields.io/badge/python-3.6-green.svg)
![MATLAB v7](https://img.shields.io/badge/MATLAB-v7-yelow.svg)

## Описание
Расчет запаса хода электробуса в километрах для каждого момента движения.

## Проблема
Изначально запас хода электробуса считался через средний расход заряда батареи за какое-то определенное время, но этот подход не учитывал множество факторов(будущие пробки, стиль вождение и т.д.), поэтому алгоритм был неточен. У нас была собрана большая база логов, которую можно было использовать для анализа. Было принято решение использовать ML, так как предполагалось, что какие-то параметры сигналов в разные дни движения могут иметь схожие паттерны, которые может распознать нейросеть.

## Решение
Было отобрано определенное количество сигналов и изначально для обучения была взята LSTM модель, так как идея была в том, что по какому-то начальному отрезку пути, зная еще дату и время, мы сможем предсказать, как будет менятся дородная обстановка в течении 2 часов. Но такое решение не давало достаточную точность даже на ближайшее время, поэтому было решено попробовать использовать XGB c преобразованием входящих параметров под временные ряды.

## Решение от начала до конца

### Датасет и обработка

<p>Датасет состоял из нескольких терабайт, зашифрованных в формате MF4, логов, в которых были записаны несколько сотен сигналов от систем электробуса. Многие сигналы могли отсутсвовать в одних логах и присутсвовать в других. Сигналы имеющие наибольшее влияние на запас хода выбирались посредством эвристики и анализа похожих решений, полноценный GridSearch сделать с таким количеством неоднородных сигналов было тяжело. Для расшифровки логов был написан конвертор в матлаб, для удобства основная обработка логов была написана так же в матлаб. Первоначально для LSTM были выбранны такие признаки: Температура уличная - outside_temperature, скорость электробуса - WheelBasedVehicleSpeed, Климат контроль(вкл/выкл) - Total_system_power, контроль открытия дверей -  DoorsOpen_CC и т.д., Ток - B2V_TotalI, а так же точное время суток в каждый момент времени, день, месяц и год. Заряд батареи (B2V_SOC) - таргет.</p>
<p>Когда было протестирован алгоритм на LSTM, было решено попробовать XGBoosting, также был изменен набор признаков и таргет: скорость, ток, SOC, температура и масса электробуса. Точной массы электробуса в любой момент времени мы получить не можем, поэтому была применена эвристика.</p>
Для нейросетей важна не сама масса, а зависимость таргета(запаса хода) от нее. Было выдвинуто предположение, что масса зависит от маршрута, отсюда предполагается, что зависимость таргета от маршрута будет включать в себя зависимость таргета от массы. Поэтому было решено использовать маршрут в качестве признака вместо массы. Любой маршрут можно найти зная скорость электробуса и поворот руля за некоторое время движения. Скорость электробуса уже используется в качестве признака, поэтому был добавлен дополнительный признак - поворот руля. Так же были убраны все остальные признаки, которые оказались самыми незначимыми.</p>
<u>Итоговые признаки: </u>:
   <ol>
      <li> L_INV2TM_MotorSpeed - скорость левого привода
      <li> R_INV2TM_MotorSpeed - скорость правого привода
      <li> SteeringWheelAngle - поворот руля
      <li> Total_system_power
      <li> outside_temperature
      <li> B2V_Totali
      <li> B2V_SOC
      <li> Day
      <li> Month
      <li> Year
      <li> Seconds
      <li> Minutes
      <li> Hours
      <li> LocalMinuteOffset
      <li> LocalHourOffset
    </ol>
Далее были конвертированы с частотой дискретизации в 0.1 в матфайлы все логи, получилось 2600 файлов.
Далее с помощью matlab кода из файлов были убраны все строки, которые содержат Nan значения, а так же файлы, в которых не хватало сигналов(<15) и убраны строки, где происходила зарядка, а так же из L_INV2TM_MotorSpeed,R_INV2TM_MotorSpeed было выведено расстояние, которое электробусы проезжали с момента начала лога до текущего момента времени и эта величина была добавлена, как новый столбец S. В итоге после обработок получилось 944 файла содержащий примерно 2-3 млн строк каждый.
XGB не работает с временными рядами, но при этом прошлые изменения нам были важны, поэтому добавлены дополнительные признаки. В качестве дополнительных признаков принято решение добавить средние показатели скорости, ток и soc, за предыдущие 10 минут движения. Расчет средних показателей  начинается с начала движения, поэтому для первых 10 минут, используются только те сигналы, что только начали поступать.
Далее принято решение в качестве таргета использовать запас хода в каждый момент времени, который выводится из логов следующим образом - берется, последний показатель S(конечная) в мат-файле, и для (n) строки, где n от 1 до кол-во строк в логе, Таргет(n) = S(конечная) - S(n). Так как в логах далеко не всегда SOC доходит до 0, для таких случаев было принято, что
{S(конечная) = S(конечная) + (SOC(конечный)/ Средняя скорость разряда SOC)*Среднее пройденное расстояние за единицу SOC}.
В таком варианте решения, зарядка электробуса будет очень сильно портить данные и путать нейросеть, поэтому принято решение такие строки  убрать, а лог с зарядкой разделять на мат-файлы до зарядки и после, таким же образом были убраны логи с долгой остановкой. Таким образом мы получаем точную модель, которая учитывает временные ряды, а в качестве таргета сразу выводим запас хода в километрах.

### Обучение
Модели были созданы, обучены и протестированы в python, код с комментариями представлен в SOC_AI


## Варианты дальнейших улучшений
Было замечено, что моменты, когда электробус долго стоит без движения не в пробке или не на светофоре, очень плохо влияют на расчет остаточного пробега, особенно, когда такое событие занимает большую часть лога, это может привести к тому, что в некоторых моментах при заряде в 100 процентов запас хода может быть около 0. Поэтому решено эти моменты убрать таким же способом, как были убраны моменты зарядки, а детектировать эти моменты с помощью сигнала от стояночного тормоза.
