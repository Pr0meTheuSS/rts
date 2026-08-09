# ZoomPlan

Этот документ описывает план физики `Zoom`. Сейчас это не план реализации по строкам кода, а спецификация физической логики и архитектурных требований. Пока работаем только с этим документом.

Главная цель `Zoom`: реалистичная, но не переусложненная модель машины. `Duvet` полезен как источник идеи про моменты, двигатель, трансмиссию и сваренный дифференциал, но он нестабилен и слишком запутан. `Pogo` полезен как законченная машина с рабочей подвеской и понятной организацией сцены, но его тяга и сцепление слишком аркадные.

## Текущие Решения

- Единственная точка входа в симуляцию машины: встроенный `CarZoom._physics_process(delta)`.
- Автоматической коробки не будет. Только ручное переключение передач.
- Должен появиться `BrakeZoom`.
- У каждого `SuspensionZoom` свой инстанс `BrakeZoom` дочерним узлом.
- `ChassisZoom` имеет право найти `SuspensionZoom` через `get_children()` и записать их в массивы: все подвески, рулевые, ведущие.
- `ChassisZoom` нужен не только как хранилище настроек, но и как владелец списков подвесок.
- Отдельные классы структур данных сейчас не нужны.
- Узлы получают входные данные через параметры вызываемых функций.
- Если функция меняет несколько результатов, она записывает их во внутренние переменные своего узла, а другие узлы потом читают их через `get_*()` методы.
- Не нужно отдельно уточнять логику потребления событий в `InputAgent`. `CarZoom` просто читает нужные input strength каждый физический кадр.
- Старой функции `get_point_velocity()` доверять нельзя. Для `Zoom` нельзя переносить ее как готовое решение.
- Если обороты двигателя ниже холостых, сцепление автоматически прожимается, чтобы двигатель не глох.
- Шины желательно считать через Pacejka / Magic Formula. Для настройки можно использовать `Curve` ресурсы, как уже используется кривая момента двигателя.
- У `ChassisZoom` есть переключатель `use_tire_curves`: если он выключен, шины используют числовые параметры Pacejka; если включен, продольная и боковая чистые силы берутся из экспортированных `Curve` ресурсов.
- На околонулевых скоростях симуляция обязана быть устойчивой и не трястись.
- Low-speed режим шин должен иметь гистерезис: вход ниже `low_speed_enter`, выход выше `low_speed_exit`, без щелчков на границе.
- Большой продольный slip должен уменьшать боковое сцепление шины до эллипса, иначе задняя ось при wheelspin сохраняет слишком много бокового держака и power oversteer не возникает.
- Пассивные потери колес и оси должны быть моментами вращения, а не центральной силой кузова. Они замедляют колесо/ось, создают slip, и только через шину появляется сила на кузове.
- Дым от шин является визуальным следствием рассеиваемой мощности в контакте шины с землей. Он не влияет на физику и передается в колесо только через `Wheel.set_smoke_ratio()`.
- Нейтраль - это разорванный путь момента, а не обычная передача с физически используемым нулевым ratio. Любое деление на передаточное число разрешено только после проверки, что передача включена и путь момента открыт.
- Руль не должен иметь аркадного ограничения максимального угла от скорости. `steer_speed` и `steer_return_speed` ограничивают только скорость движения рулевого механизма к целевому углу.
- Для проверки скорости контакта колес надо публиковать диагностику обоих центров вращения: `CENTER_OF_MASS` и `BODY_ORIGIN`. Физика использует выбранный режим, а мониторы показывают `COM - BODY` по `Vx` и `Vy` для каждого колеса.

## Обязательные Узлы

```text
CarZoom (RigidBody3D)
  EngineZoom (Node)
  ClutchZoom (Node)
  TransmissionZoom (Node)
  WeldedDiffZoom (Node)
  ChassisZoom (Node3D)
	SuspensionZoomFL (Node3D)
	  RayCast3D
	  Wheel
	  BrakeZoom
	SuspensionZoomFR (Node3D)
	  RayCast3D
	  Wheel
	  BrakeZoom
	SuspensionZoomRL (Node3D)
	  RayCast3D
	  Wheel
	  BrakeZoom
	SuspensionZoomRR (Node3D)
	  RayCast3D
	  Wheel
	  BrakeZoom
```

## Ответственность Узлов

### CarZoom

`CarZoom` - единственный оркестратор физического кадра.

Он:

- хранит ссылки на `EngineZoom`, `ClutchZoom`, `TransmissionZoom`, `WeldedDiffZoom`, `ChassisZoom`;
- создает и запускает `InputAgent`;
- читает газ, тормоз, сцепление, руль, gear up, gear down, reset;
- вызывает методы остальных узлов в правильном порядке;
- не отдает управление физикой в дочерние `_physics_process()`;
- в конце кадра вызывает `apply_force()` для сил подвески и шин;
- делает reset машины.

`CarZoom` не должен генерировать аркадные центральные силы разгона или торможения. Итог движения машины должен получаться через силы в точках колес.

### ChassisZoom

`ChassisZoom` - владелец компоновки шасси, настроек колес и массивов подвесок.

Он:

- в `_ready()` проходит по детям через `get_children()`;
- собирает массив `all_suspensions`;
- собирает массив `steer_suspensions`;
- собирает массив `drive_suspensions`;
- конфигурирует каждую подвеску общими параметрами колеса, подвески, шин и признаками `is_steer`, `is_drive`;
- считает текущий угол руля;
- вызывает методы подвесок пачкой, если это удобнее;
- предоставляет `get_all_suspensions()`, `get_drive_suspensions()`, `get_steer_suspensions()`;
- предоставляет суммарные результаты по ведущим колесам, например `get_drive_ground_torque_sum()` и `get_drive_brake_torque_sum()`.

`ChassisZoom` может хранить ссылки на свои дочерние `SuspensionZoom`. Это не нарушает архитектуру: подвески являются частью шасси.

### SuspensionZoom

`SuspensionZoom` - физика одного колесного модуля.

Он хранит:

- `is_drive`;
- `is_steer`;
- `wheel_radius`;
- `wheel_inertia`;
- `_wheel_omega` для свободного неведущего колеса;
- `_last_length`;
- `_grounded`;
- `_hub_point`;
- `_contact_point`;
- `_normal`;
- `_long_dir`;
- `_lat_dir`;
- `_load`;
- `_suspension_force`;
- `_tire_force`;
- `_ground_torque`;
- `_last_vx`;
- `_last_vy`;
- `_last_slip_ratio`;
- `_last_slip_angle`;
- `_last_ellipse_usage`.

Он:

- имеет внутренние ссылки на свой `RayCast3D`, `Wheel`, `BrakeZoom`;
- считает силу подвески;
- считает скорость контакта в продольном и поперечном направлении по данным, полученным от `CarZoom`;
- считает силу шины;
- записывает результат во внутренние переменные;
- возвращает результаты через `get_*()` методы;
- не вызывает `apply_force()` сам.

### BrakeZoom

`BrakeZoom` - тормоз одного колеса.

Он:

- находится внутри своего `SuspensionZoom`;
- хранит `max_torque`;
- получает `brake_input`;
- считает тормозной момент на колесо;
- не прикладывает силу к кузову;
- для ведущих колес отдает тормозной момент в общую ведущую ось;
- для свободных колес тормозит собственную `_wheel_omega` подвески;
- умеет удерживать колесо/ось в нуле, если тормозной момент достаточен.

Тормоз не должен напрямую создавать продольную силу кузова. Продольная тормозная сила появляется только через шину: тормозной момент меняет вращение колеса, возникает slip, шина создает `Fx`, а `Fx` прикладывается к кузову.

### EngineZoom

`EngineZoom` - двигатель и маховик.

Он хранит:

- `omega`;
- `moment_of_inertia`;
- `torque_curve`;
- `idle_rpm`;
- `redline_rpm`;
- внутреннее трение;
- engine brake;
- параметры idle controller.

Он:

- считает момент двигателя по кривой и газу;
- поддерживает холостые обороты;
- не должен глохнуть;
- при закрытом газе может создавать отрицательный момент engine braking;
- получает момент сопротивления от сцепления;
- интегрирует свою `omega`.

Если обороты ниже холостых, это не повод заглушить двигатель. В этом случае `ClutchZoom` должен автоматически разомкнуть сцепление, а `EngineZoom` должен вернуться к холостым за счет idle controller.

Engine braking - это не ошибка сохранения энергии. В этом режиме энергия вращения колес и поступательного движения машины через шины, ведущую ось, коробку и сцепление уходит в двигатель, а там рассеивается внутренними потерями и насосными потерями.

### ClutchZoom

`ClutchZoom` - сцепление между двигателем и трансмиссией.

Он хранит:

- `max_torque`;
- текущую степень замыкания;
- скорость замыкания и размыкания;
- idle protection thresholds.

Он:

- получает положение педали сцепления;
- получает обороты двигателя;
- получает состояние коробки;
- если двигатель ниже холостых, автоматически уменьшает замыкание;
- считает момент, который пытается синхронизировать двигатель и вход трансмиссии;
- ограничивает этот момент своей текущей емкостью;
- возвращает один момент: на двигатель он действует с противоположным знаком, на трансмиссию с прямым.

Сцепление может проскальзывать. Потеря энергии при проскальзывании считается теплом и не должна компенсироваться где-то еще.

### TransmissionZoom

`TransmissionZoom` - ручная коробка передач.

Он хранит:

- массив передних передач;
- заднюю передачу;
- нейтраль;
- текущую передачу;
- таймер переключения, если нужен;
- входную инерцию, если позже понадобится.

Он:

- обрабатывает только ручные `gear_up` и `gear_down`;
- не содержит автоматического переключения;
- не использует `await`;
- при нейтрали сообщает, что активного передаточного числа нет;
- не должен заставлять остальные узлы делить на `0`;
- передаточное число используется только когда `can_transmit_torque() == true`;
- при переключении может временно разрывать путь момента;
- переводит момент сцепления в момент на выходе коробки через передаточное число;
- переводит угловую скорость ведущей оси к стороне сцепления через передаточное число.

### WeldedDiffZoom

`WeldedDiffZoom` - сваренный дифференциал и общая ведущая ось.

Он хранит:

- `final_drive`;
- `axle_omega`;
- инерцию дифференциала/оси;
- drag момента оси.

Он:

- дает одну общую угловую скорость всем ведущим колесам;
- суммирует моменты от двигателя, тормозов, шин и внутренних потерь;
- интегрирует `axle_omega`;
- не распределяет момент как открытый дифференциал;
- допускает, что левое и правое ведущее колесо имеют разные силы шины, но один общий `omega`.

## Главные Физические Инварианты

- Двигатель может добавлять энергию в систему при положительном моменте сгорания.
- Двигатель может забирать энергию из системы при торможении двигателем.
- Тормоза, сцепление при проскальзывании, шины при скольжении и демпферы подвески только рассеивают энергию.
- Коробка и главная пара в первом варианте считаются идеальными передачами.
- Идеальная передача сама не создает и не уничтожает энергию: она меняет момент и угловую скорость так, чтобы мощность до потерь сохранялась.
- Разные передачи обязаны по-разному связывать двигатель и шасси: при том же `axle_omega` двигатель получает разные обороты, а тот же момент двигателя превращается в разный момент на ведущей оси.
- Сила шины на кузов и момент реакции земли на колесо должны быть связаны:

```text
tau_ground = -Fx * wheel_radius
```

- Если колесо толкает кузов вперед, земля тормозит вращение колеса.
- Если тормоз замедляет колесо, продольная сила возникает только через контакт шины.
- Нет отдельной центральной силы разгона.
- Нет отдельной центральной силы торможения.
- Боковая сила шины всегда направлена против бокового скольжения.
- Продольная сила шины должна иметь знак, уменьшающий продольный slip, кроме случаев внешнего двигателя/тормоза, где slip остается из-за нехватки сцепления.
- Комбинированное продольное и поперечное сцепление ограничивается эллипсом.

## Нейтраль И Передаточные Числа

Нейтраль нельзя рассматривать как обычную передачу с ratio `0`, если это ratio потом участвует в делении. В физической логике нейтраль означает отсутствие кинематической связи между двигателем и ведущей осью.

Требования:

- у `TransmissionZoom` должен быть явный ответ `can_transmit_torque()`;
- если включена нейтраль, `can_transmit_torque() == false`;
- если идет переключение и путь момента разорван, `can_transmit_torque() == false`;
- `total_ratio` считается только когда `can_transmit_torque() == true`;
- `omega_driven_at_clutch`, `reflected_inertia`, `axle_drive_torque` не считаются через ratio в нейтрали;
- в нейтрали `clutch_torque = 0` для связи с колесами, даже если сцепление физически отпущено;
- двигатель в нейтрали живет как свободный двигатель с маховиком, idle controller и engine braking.

Псевдологика:

```text
if transmission.can_transmit_torque():
	total_ratio = transmission.get_active_ratio() * welded_diff.final_drive
	omega_driven_at_clutch = axle_omega * total_ratio
	reflected_inertia = axle_inertia / (total_ratio * total_ratio)
	axle_drive_torque = clutch_torque * total_ratio
else:
	total_ratio = none
	omega_driven_at_clutch = none
	reflected_inertia = none
	clutch_torque = 0
	axle_drive_torque = 0
```

`get_active_ratio()` не должен вызываться как источник физического ratio, если `can_transmit_torque() == false`.

## Передачи И Обмен Энергией

Разные передачи должны менять характер обмена энергии между двигателем и шасси. Это не отдельный хак, а ожидаемое emergent-поведение правильной связи через `total_ratio`.

При замкнутом пути момента:

```text
omega_engine_side = axle_omega * total_ratio
torque_axle = clutch_torque * total_ratio
```

Поэтому:

- на низкой передаче `abs(total_ratio)` больше;
- тот же момент двигателя дает больший момент на ведущей оси;
- та же скорость машины дает большие обороты двигателя;
- engine braking через сцепление сильнее тормозит ведущую ось;
- момент инерции шасси, отраженный к двигателю, меняется как `1 / total_ratio^2`;
- момент инерции двигателя, отраженный к ведущей оси, меняется как `total_ratio^2`.

Если модель сцепления, коробки и дифференциала использует эти связи, различие передач должно возникать само. Это нужно потом проверить отдельным тестом: одинаковая скорость машины, разные передачи, отпущенный газ, сцепление замкнуто - замедление от engine braking должно отличаться.

## Скорость Точки Контакта

Старую `get_point_velocity()` из предыдущих моделей не переносить как доверенную.

Для `Zoom` нужно отдельно и аккуратно определить скорость точки контакта. Физически требуется:

```text
contact_velocity = linear_velocity + angular_velocity x (contact_point - rotation_center)
```

Тонкое требование: перед доверием этой формуле нужно проверить, какая точка в Godot фактически является корректным `rotation_center` для текущего `RigidBody3D`: `center_of_mass`, `global_position` или центр масс в мировой системе. Ошибка здесь ломает slip, особенно на малой скорости.

Практическая проверка `rotation_center`:

- Включить в `CarZoom.contact_velocity_center` режим `CENTER_OF_MASS`, затем `BODY_ORIGIN` и сравнить debug величины `Vx`, `Vy`, `slip_ratio`, `slip_angle` по колесам.
- На прямом движении без руля у левых и правых колес `Vy` должен быть близок к нулю и симметричен.
- В плавном повороте разница скоростей левых и правых колес должна соответствовать знаку yaw: внешние колеса проходят большую дугу, внутренние меньшую.
- При вращении кузова вокруг yaw без большой поступательной скорости вклад `angular_velocity.cross(contact_point - rotation_center)` должен давать понятные разные скорости в точках колес, а не случайный боковой slip.
- Правильный кандидат для Godot обычно мировой центр масс: `to_global(center_of_mass)`, если `center_of_mass_mode` использует custom center of mass. `global_position` оставлен как переключаемый режим для сравнения.

До подтверждения нельзя строить неустойчивую модель, полностью зависящую от точной эффективной массы в точке. Поэтому v1 использует:

- проверенную скорость контакта от `CarZoom`;
- ограничение сил по знаку, чтобы они не переворачивали slip через ноль;
- низкоскоростной режим шин, не основанный на делении на почти нулевую скорость;
- сглаживание и deadband около нуля.

## Шины: Pacejka И Эллипс Сцепления

Базовая модель шины:

1. Посчитать нормальную нагрузку `Fz` от подвески.
2. Посчитать продольную скорость контакта `Vx`.
3. Посчитать поперечную скорость контакта `Vy`.
4. Посчитать скорость поверхности колеса:

```text
wheel_surface_speed = wheel_omega * wheel_radius
```

5. Посчитать продольный slip:

```text
slip_velocity_x = wheel_surface_speed - Vx
slip_ratio = slip_velocity_x / max(abs(Vx), slip_speed_reference)
```

В denominator нельзя добавлять `abs(wheel_surface_speed)`, иначе сильный wheelspin искусственно сжимается к `slip_ratio == 1`. На малой скорости устойчивость обеспечивается не этой нормализацией, а low-speed моделью через `slip_velocity_x`, deadband, rate limit и гистерезис.

6. Посчитать slip angle:

```text
slip_angle = atan2(Vy, max(abs(Vx), lateral_speed_reference))
```

7. Получить чистую продольную силу из Pacejka или `Curve`:

```text
Fx_pure = Fz * mu_longitudinal * pacejka_longitudinal(slip_ratio)
```

`pacejka_longitudinal()` должна возвращать знак slip ratio. Если `slip_ratio > 0`, `Fx_pure > 0`.

8. Получить чистую боковую силу из Pacejka или `Curve`:

```text
Fy_pure = -Fz * mu_lateral * pacejka_lateral(slip_angle)
```

`pacejka_lateral()` должна возвращать знак slip angle. Минус нужен, чтобы боковая сила противодействовала `Vy`.

9. На малых скоростях смешать Pacejka с низкоскоростной вязко-статической моделью:

```text
Fx_low = longitudinal_low_speed_stiffness * slip_velocity_x
Fy_low = -lateral_low_speed_stiffness * Vy
low_speed_blend = low_speed_blend_curve.sample(contact_speed)
Fx_raw = lerp(Fx_low, Fx_pure, low_speed_blend)
Fy_raw = lerp(Fy_low, Fy_pure, low_speed_blend)
```

При `contact_speed` около нуля `low_speed_blend` близок к `0`. На нормальной скорости он близок к `1`.

10. Применить combined-slip затухание боковой силы от продольного slip:

```text
t = inverse_lerp(
	longitudinal_slip_lateral_fade_start,
	longitudinal_slip_lateral_fade_end,
	abs(slip_ratio)
)
lateral_slip_scale = 1 - smoothstep01(clamp(t, 0, 1))
Fy_raw *= lateral_slip_scale
```

Это нужно потому, что чистая Pacejka ограничивает `Fx_pure` около пика и сама по себе не сообщает эллипсу, насколько жестокий wheelspin происходит. При большом продольном slip задняя шина должна терять способность держать боковую силу, иначе power oversteer получается слишком слабым.

11. Ограничить `Fx_raw` и `Fy_raw` эллипсом сцепления:

```text
(Fx / Fx_max)^2 + (Fy / Fy_max)^2 <= 1
Fx_max = Fz * mu_longitudinal
Fy_max = Fz * mu_lateral
```

Если точка вне эллипса, масштабировать обе силы одним коэффициентом:

```text
scale = 1 / sqrt((Fx_raw / Fx_max)^2 + (Fy_raw / Fy_max)^2)
Fx = Fx_raw * scale
Fy = Fy_raw * scale
```

12. Записать момент реакции земли на колесо:

```text
ground_torque = -Fx * wheel_radius
```

13. Записать силу шины в мире:

```text
tire_force = Fx * long_dir + Fy * lat_dir
```

14. Посчитать визуальный дым от рассеиваемой мощности контакта:

```text
longitudinal_slip_power = max(Fx * slip_velocity_x, 0)
lateral_slip_power = max(-Fy * Vy, 0)
tire_slip_power = longitudinal_slip_power + lateral_slip_power

longitudinal_smoke_factor = smoothstep(
	smoke_longitudinal_slip_start,
	smoke_longitudinal_slip_full,
	abs(slip_ratio)
)

lateral_smoke_factor = smoothstep(
	deg_to_rad(smoke_lateral_angle_start_deg),
	deg_to_rad(smoke_lateral_angle_full_deg),
	abs(slip_angle)
)

tire_smoke_power =
	longitudinal_slip_power * longitudinal_smoke_factor
	+ lateral_slip_power * lateral_smoke_factor

smoke_heat += tire_smoke_power * dt / smoke_heat_capacity
smoke_heat -= smoke_heat * smoke_cooling_rate * dt
smoke_heat = max(smoke_heat, 0)

smoke_ratio = smoothstep(
	smoke_visible_heat_start,
	smoke_visible_heat_full,
	smoke_heat
)

Wheel.set_smoke_ratio(smoke_ratio)
```

`Fx * slip_velocity_x` дает тепло от продольного букса или блокировки. `-Fy * Vy` дает тепло от бокового скольжения, потому что боковая сила должна быть направлена против `Vy`.

Обычный поворот не должен мгновенно дымить: `slip_angle` мал, `lateral_smoke_factor` близок к нулю, а накопленное `smoke_heat` успевает остывать. Burnout с места дымит после накопления тепла: `slip_ratio` большой, `longitudinal_smoke_factor` близок к единице, и энергия скольжения быстро греет шину.

Старые параметры вида `smoke_rise_rate`/`smoke_fall_rate` были только визуальным сглаживанием `smoke_ratio`; физического смысла у них почти не было. В тепловой модели их заменяют `smoke_heat_capacity` и `smoke_cooling_rate`.

## Pacejka Через Formula Или Curve

Допустимы два варианта.

Вариант A: Magic Formula:

```text
y = D * sin(C * atan(B * x - E * (B * x - atan(B * x))))
```

Где:

- `x` для продольной силы - `slip_ratio`;
- `x` для боковой силы - `slip_angle`;
- `y` желательно нормализовать примерно в диапазон `[-1, 1]`;
- `D` можно оставить `1`, а фактический лимит задавать через `Fz * mu`.

Вариант B: `Curve` ресурсы:

- `longitudinal_pacejka_curve`: вход `slip_ratio`, выход нормализованная сила `[-1, 1]`;
- `lateral_pacejka_curve`: вход `slip_angle`, выход нормализованная сила `[-1, 1]`;
- `load_sensitivity_curve`: опциональная поправка `mu` от нагрузки;
- `low_speed_blend_curve`: переход от низкоскоростной модели к Pacejka.

На этой стадии можно описать оба варианта, но при реализации лучше начать с `Curve`, потому что ее проще тюнить в редакторе, как кривую двигателя.

Текущая реализация поддерживает оба варианта:

- `use_tire_curves == false`: используются `pacejka_longitudinal_b/c/e` и `pacejka_lateral_b/c/e`.
- `use_tire_curves == true`: используются `longitudinal_tire_curve` и `lateral_tire_curve`.
- Если домен `Curve` начинается с отрицательных значений, кривая семплится по исходному signed slip.
- Если домен `Curve` только положительный, семплится `abs(slip)`, а знак возвращается отдельно. Это удобно для симметричных кривых 0..1.

## Нулевая И Околонулевая Скорость

Это отдельное жесткое требование. Машина не должна дрожать на месте.

На малых скоростях нельзя использовать чистый slip ratio как главный источник силы, потому что деление на маленький `Vx` взрывает знак и величину.

Правила:

- Ни одна формула не должна делить на скорость меньше `slip_speed_reference`.
- У шин есть режим `low_speed`, основанный на `slip_velocity_x` и `Vy`, а не на бесконечном slip ratio.
- У тормозов есть режим удержания нуля.
- У сцепления есть idle protection, чтобы двигатель не дергал машину при падении ниже холостых.
- Сила шины около нуля должна иметь deadband.
- Изменение силы шины можно ограничить `force_rate_limit`, чтобы она не прыгала между `+Fx` и `-Fx` каждый кадр.
- Если колесо почти стоит, тормоз нажат, и внешние моменты меньше тормозной емкости, колесо остается в нуле.
- Если ведущая ось почти стоит, тормоз нажат, и сумма внешних моментов меньше тормозной емкости, `axle_omega` остается в нуле.
- Если машина стоит без газа и тормоза, итоговые `Fx` и `Fy` должны стремиться к нулю.

Рекомендуемые параметры:

```text
low_speed_enter = 0.5 m/s
low_speed_exit = 1.5 m/s
slip_speed_reference = 1.0 m/s
static_omega_threshold = 0.5 rad/s
force_deadband = small value around 1..10 N
```

Нужен гистерезис: вход в low-speed и выход из него должны иметь разные пороги, иначе режим будет щелкать туда-сюда.

Текущая логика low-speed:

```text
if low_speed_active:
	if contact_speed >= low_speed_exit:
		low_speed_active = false
else:
	if contact_speed <= low_speed_enter:
		low_speed_active = true

target_blend = 0 if low_speed_active else 1
low_speed_blend moves toward target_blend by low_speed_blend_rate
```

Так режим имеет память, а сила не прыгает мгновенно между low-speed и Pacejka.

## Пассивные Потери Колес

Если сцепление разомкнуто, машина все равно должна постепенно замедляться от пассивных потерь. Это нельзя делать центральной силой.

Для каждого колеса используется пассивный момент:

```text
passive_torque =
	-wheel_viscous_drag * wheel_omega
	-sign(reference) * wheel_constant_drag
	-sign(reference) * rolling_resistance_coefficient * Fz * wheel_radius
```

`reference` берется из `wheel_omega`, а если колесо почти стоит - из продольной скорости контакта `Vx`.

Для свободного колеса этот момент входит в локальную интеграцию `_wheel_omega`.

Для ведущего колеса этот момент суммируется в `ChassisZoom.get_drive_passive_torque_sum()` и передается в `WeldedDiffZoom` как часть момента общей ведущей оси.

Пассивные потери не прикладывают силу напрямую к кузову. Они меняют вращение колеса, затем шина через slip создает `Fx`.

## Сцепление И Защита От Глохнущего Двигателя

Сцепление имеет три источника размыкания:

- педаль сцепления;
- переключение передачи;
- защита двигателя ниже холостых.

Логика:

```text
manual_engagement = 1 - clutch_input
shift_engagement = 0 if transmission_is_shifting else 1

if engine_rpm < idle_rpm:
	idle_protection_engagement = 0
elif engine_rpm > idle_rpm + idle_resume_margin:
	idle_protection_engagement = 1
else:
	keep previous / smoothly interpolate

target_engagement = min(manual_engagement, shift_engagement, idle_protection_engagement)
current_engagement moves toward target_engagement
clutch_capacity = max_clutch_torque * current_engagement
```

Если двигатель начинает падать ниже холостых, сцепление автоматически прожимается. Это важнее реализма заглохшего двигателя: в `Zoom` двигатель не должен глохнуть.

Момент сцепления:

```text
omega_engine = engine.omega
omega_driven = welded_diff.axle_omega * total_ratio
omega_error = omega_engine - omega_driven
ideal_sync_torque tries to reduce omega_error
clutch_torque = clamp(ideal_sync_torque, -clutch_capacity, clutch_capacity)
```

На двигатель действует:

```text
engine_net_torque = engine_torque - clutch_torque
```

На трансмиссию действует:

```text
transmission_input_torque = clutch_torque
```

## Тормоза

Каждый `BrakeZoom` считает тормозной момент своего колеса.

```text
brake_capacity = max_torque * brake_input
```

Если колесо/ось вращается:

```text
brake_torque = -sign(omega) * brake_capacity
```

Если колесо/ось почти стоит:

```text
if abs(external_torque_without_brake) <= brake_capacity:
	brake_torque = -external_torque_without_brake
	omega stays 0
else:
	brake_torque = -sign(external_torque_without_brake) * brake_capacity
```

Для свободного колеса `external_torque_without_brake` включает `ground_torque` шины.

Для ведущего колеса тормозной момент идет в сумму тормозных моментов ведущей оси, а удержание нуля делает `WeldedDiffZoom`.

## Укороченный Псевдокод Полного Физического Цикла

Это логика одного кадра. Это не финальный GDScript, а порядок физических процессов.

```text
CarZoom._physics_process(delta):
	dt = safe_delta(delta)

	throttle = input_agent.get_strength(THROTTLE)
	brake = input_agent.get_strength(BRAKE)
	clutch_input = input_agent.get_strength(CLUTCH)
	steer = input_agent.get_strength(STEER)
	gear_up = input_agent.get_strength(GEAR_UP) > 0
	gear_down = input_agent.get_strength(GEAR_DOWN) > 0
	reset = input_agent.get_strength(RESET) > 0 or Input reset pressed

	if reset:
		reset_car()
		return

	if gear_up:
		transmission.gear_up()
	if gear_down:
		transmission.gear_down()

	transmission.update(dt)

	chassis.update_steer(dt, steer, car_speed)

	chassis.sample_suspensions(
		dt,
		car_global_transform,
		car_linear_velocity,
		car_angular_velocity,
		verified_rotation_center
	)

	engine_torque = engine.calculate_torque(throttle)

	path_open = transmission.can_transmit_torque()

	if path_open:
		total_ratio = transmission.get_active_ratio() * welded_diff.get_final_drive()
		driven_omega_at_clutch = welded_diff.get_axle_omega() * total_ratio
	else:
		total_ratio = none
		driven_omega_at_clutch = none

	clutch.update_engagement(
		dt,
		clutch_input,
		transmission.is_shifting(),
		engine.get_rpm(),
		engine.get_idle_rpm(),
		path_open
	)

	if path_open:
		clutch_torque = clutch.calculate_torque(
			dt,
			engine.get_omega(),
			driven_omega_at_clutch,
			engine.get_inertia(),
			welded_diff.get_reflected_inertia_to_clutch(total_ratio)
		)
	else:
		clutch_torque = 0

	axle_drive_torque = 0
	if path_open:
		axle_drive_torque = clutch_torque * total_ratio

	chassis.update_brakes(brake)

	welded_diff.predict_axle_omega(
		dt,
		axle_drive_torque,
		chassis.get_drive_brake_torque_guess_sum()
	)

	chassis.solve_tires(
		dt,
		welded_diff.get_predicted_axle_omega(),
		tire_model_mode = Pacejka_with_low_speed_blend
	)

	welded_diff.integrate(
		dt,
		axle_drive_torque,
		chassis.get_drive_ground_torque_sum(),
		chassis.get_drive_brake_torque_final_sum()
	)

	chassis.integrate_free_wheels(dt)

	engine.integrate(
		dt,
		engine_torque - clutch_torque
	)

	for suspension in chassis.get_all_suspensions():
		if suspension.is_grounded():
			apply_force(
				suspension.get_suspension_force(),
				suspension.get_hub_point() - global_position
			)

			apply_force(
				suspension.get_tire_force(),
				suspension.get_contact_point() - global_position
			)

		suspension.update_visual()
```

## Подробность По Порядку Кадра

### 1. Ввод

`CarZoom` каждый кадр читает текущие значения инпутов. Никакой дополнительной логики потребления событий в плане описывать не нужно.

### 2. Ручная Коробка

Если пришел `gear_up` или `gear_down`, `TransmissionZoom` меняет передачу. Автоматического выбора передачи нет.

Во время переключения путь момента может быть разорван, чтобы не было мгновенного жесткого удара.

### 3. Подвеска И Контакт

`ChassisZoom` вызывает у каждой подвески расчет:

- raycast;
- сжатие;
- скорость сжатия;
- сила пружины;
- сила демпфера;
- нормальная нагрузка;
- продольная и поперечная оси контакта;
- `Vx` и `Vy` в точке контакта.

Сила подвески записывается в `SuspensionZoom`, но еще не применяется.

### 4. Двигатель

`EngineZoom` считает момент по оборотам и газу. Если обороты около холостых, idle controller помогает держать двигатель живым.

### 5. Сцепление

`ClutchZoom` считает, насколько сцепление замкнуто.

Если `engine_rpm < idle_rpm`, сцепление автоматически размыкается. Это требование важнее возможности заглохнуть.

### 6. Трансмиссия И Дифференциал

Если передача включена и путь момента открыт:

```text
total_ratio = active_gear_ratio * final_drive
omega_driven_at_clutch = axle_omega * total_ratio
axle_drive_torque = clutch_torque * total_ratio
```

Если нейтраль или переключение:

```text
total_ratio = none
omega_driven_at_clutch = none
reflected_inertia = none
clutch_torque = 0
axle_drive_torque = 0
```

В нейтрали не делить на `total_ratio`. Нейтраль - это отсутствие связи, а не передача с рабочим нулевым числом.

### 7. Тормоза

Каждая подвеска вызывает свой `BrakeZoom`.

Свободные колеса используют тормозной момент локально.

Ведущие колеса передают свои тормозные моменты в `WeldedDiffZoom`, потому что у них общий `axle_omega`.

### 8. Шины

Каждая подвеска считает `Fx` и `Fy`.

Для ведущих колес используется предсказанная `axle_omega`.

Для свободных колес используется собственная предсказанная `_wheel_omega`.

Сначала считаются чистые силы Pacejka/Curve, затем они смешиваются с низкоскоростной моделью, затем ограничиваются эллипсом.

После этого:

```text
ground_torque = -Fx * wheel_radius
tire_force = Fx * long_dir + Fy * lat_dir
```

### 9. Интеграция Вращения

`WeldedDiffZoom` интегрирует общую ведущую ось:

```text
axle_net_torque =
	axle_drive_torque
	+ sum(ground_torque from drive wheels)
	+ sum(brake_torque from drive wheels)
	+ axle_drag
```

`SuspensionZoom` интегрирует свободные колеса:

```text
free_wheel_net_torque =
	ground_torque
	+ brake_torque
```

`EngineZoom` интегрирует двигатель:

```text
engine_net_torque =
	engine_torque
	- clutch_torque
```

### 10. Применение Сил

Только `CarZoom` вызывает `apply_force()`.

Для каждого заземленного колеса:

```text
apply_force(suspension_force, hub_point - car_position)
apply_force(tire_force, contact_point - car_position)
```

Это конечный итог симуляции физического кадра.

## Требования К Устойчивости

Модель считается неприемлемой, если:

- машина дрожит на месте без газа и тормоза;
- машина дрожит на месте с зажатым тормозом;
- колесо на нулевой скорости каждый кадр меняет знак `omega`;
- `Fx` на малой скорости каждый кадр меняет знак без причины;
- сцепление душит двигатель ниже холостых;
- slip ratio становится огромным из-за деления на почти нулевую скорость;
- эллипс сцепления нарушается;
- тормоз напрямую прикладывает силу к кузову.

Модель считается приемлемой для первого рабочего прототипа, если:

- машина спокойно стоит на плоскости;
- при плавном газе с места сила появляется через задние шины;
- при полном газе с места возможна пробуксовка, но без численного взрыва;
- при торможении колеса могут блокироваться без дрожания;
- при одновременном торможении и повороте боковая сила уменьшается из-за эллипса;
- при одновременном газе и повороте задние шины используют общий лимит сцепления;
- двигатель не глохнет, потому что сцепление открывается ниже холостых.

## Debug Величины

Полезно выводить:

- `engine_rpm`;
- `gear`;
- `clutch_engagement`;
- `clutch_torque`;
- `axle_omega`;
- `wheel_omega` по каждому колесу;
- `Fz`, `Fx`, `Fy` по каждому колесу;
- `slip_ratio`;
- `slip_velocity_x`;
- `slip_angle`;
- `lateral_slip_scale`;
- `ellipse_usage`;
- `ellipse_request` до ограничения эллипсом;
- `tire_slip_power`;
- `tire_smoke_power`;
- `smoke_heat`;
- `smoke_ratio`;
- нормализованные `Fx/Fx_max`, `Fy/Fy_max`, `Fx_raw/Fx_max`, `Fy_raw/Fy_max`;
- `ground_torque`;
- `passive_torque`;
- `drive_grip_torque`;
- `drive_torque_ratio`;
- `clutch_capacity_at_axle`;
- текущий режим центра вращения контактов (`COM` или `BODY`);
- `vx_body`, `vy_body`, `vx_com`, `vy_com`;
- `vx_center_delta = vx_com - vx_body`;
- `vy_center_delta = vy_com - vy_body`;
- low-speed режим включен или нет;
- brake lock включен или нет.

## Что Не Делаем Сейчас

- Не пишем финальный код.
- Не делаем автоматическую коробку.
- Не делаем open differential.
- Не делаем ABS.
- Не делаем traction control.
- Не добавляем аркадные центральные силы.
- Не считаем сложную термомодель шин.
- Не полагаемся на старую `get_point_velocity()`.

## Что Берем Из Duvet И Pogo

Из `Duvet` берем:

- поток момента от двигателя к колесам;
- общую идею сваренного дифференциала;
- связь силы шины и момента реакции на колесо.

Из `Duvet` не берем:

- запутанное распределение ответственности;
- нестабильные масштабные множители;
- прямое смешивание сил кузова и моментов колес без единой логики.

Из `Pogo` берем:

- рабочую raycast-подвеску;
- геометрию колес 350z;
- визуальные колеса;
- идею `Chassis` как владельца колес;
- рабочую схему ввода.

Из `Pogo` не берем:

- аркадную продольную тягу;
- центральные силы движения;
- упрощенную шину без полноценного комбинированного сцепления.
