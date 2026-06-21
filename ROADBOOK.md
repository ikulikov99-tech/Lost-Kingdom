# ROADBOOK — Lost Kingdom

Координаты дорог, локаций, offsets и безопасных точек клика. Построено **из реальных
данных** `Main.tscn` (Curve2D `_data`) и `MapTuningMarkers`, не по скриншоту.
Машинная версия: [`ROADBOOK.json`](ROADBOOK.json).

- Система координат: мир Godot 2D, **+x вправо, +y ВНИЗ**. `WorldMap` sprite в `(-656,-552)`.
- **Авторитетны позиции `MapTuningMarkers/Waypoints`** — в рантайме `_pos()` берёт
  `marker.global_position`, а НЕ константы `WAYPOINTS` в `Main.gd` (они расходятся,
  напр. Village: маркер `-888,-504`, константа `-928,-504`). Везде ниже — маркеры.
- `baked_length` — приближение по сумме хорд между точками кривой (тангенсы ~0,
  кривые почти ломаные). Точность ±несколько px, достаточно для прицела клика.
- Регенерация: `Main.tscn` изменился → перегенерировать ROADBOOK из кривых.

---

## Локации (Waypoints)

| id | Название | waypoint (world) | reveal center | Выходящие дороги (соседи) |
|---|---|---|---|---|
| Castle | Королевский замок | (-1088, -720) | (-1200, -816) | Village |
| Village | Деревня | (-888, -504) | (-1016, -552) | Castle, Dock, Lumbermill |
| Dock | Пристань | (-1160, -128) | (-1296, -192) | Village, KnightRuins |
| KnightRuins | Руины рыцарей | (-792, -288) | (-704, -400) | Dock, MageTower |
| MageTower | Башня мага | (-552, -272) | (-496, -248) | KnightRuins, EarthMageCastle |
| EarthMageCastle | Замок мага земли | (-432, -600) | (-512, -624) | MageTower, DarkCastle🔒, Mine |
| DarkCastle | Замок тьмы | (-176, -744) | (-200, -640) | EarthMageCastle — 🔒 LOCKED |
| Lumbermill | Лесопилка | (-624, -760) | (-680, -832) | Village, Mine |
| Mine | Заброшенная шахта | (-376, -816) | (-416, -944) | Lumbermill, EarthMageCastle |

Граф (ROUTES) — линейная цепочка с кольцом через Village:
`Castle → Village → Dock → KnightRuins → MageTower → EarthMageCastle → Mine → Lumbermill → Village`

---

## Активные дороги (Path2D, участвуют в навигации)

Для каждой: `road_id`, from→to, baked_length, концы, направление с каждой стороны,
sample-точки (offset → world, note). Note: `safe click` = безопасный шаг по дороге;
`junction` = подход к узлу/концу (там вход в локацию только кликом ≤60px в маркер).

### CastleVillagePath — Castle → Village · L≈424
Dir: из Castle ↘SE · из Village ↘SE · концы (-1088,-720)→(-888,-504)

| offset | pos | note |
|---|---|---|
| 0 | (-1088,-720) | Castle side |
| 120 | (-1002,-643) | safe click |
| 240 | (-890,-601) | safe click |
| 360 | (-842,-512) | approach Village / junction |
| end | (-888,-504) | Village endpoint |

### VillageDockPath — Village → Dock · L≈759 (длинная береговая)
Dir: из Village ↘SE · из Dock →E · концы (-888,-504)→(-1160,-128)

| offset | pos | note |
|---|---|---|
| 0 | (-888,-504) | Village side |
| 120 | (-927,-446) | safe click |
| 240 | (-960,-381) | safe click |
| 360 | (-903,-295) | safe click |
| 480 | (-905,-213) | safe click |
| 600 | (-1004,-146) | safe click |
| 720 | (-1121,-130) | approach Dock / junction |
| end | (-1160,-128) | Dock endpoint |

### DockKnightRuinsPath — Dock → KnightRuins · L≈426
Dir: из Dock →E · из KnightRuins ↙SW · концы (-1160,-128)→(-792,-288)

| offset | pos | note |
|---|---|---|
| 0 | (-1160,-128) | Dock side |
| 120 | (-1041,-136) | safe click |
| 240 | (-935,-189) | safe click |
| 360 | (-832,-240) | approach KnightRuins / junction |
| end | (-792,-288) | KnightRuins endpoint |

### VillageLumbermillPath — Village → Lumbermill · L≈469
Dir: из Village ↘SE · из Lumbermill ↘SE · концы (-888,-504)→(-620,-764)

| offset | pos | note |
|---|---|---|
| 0 | (-888,-504) | Village side |
| 120 | (-839,-565) | safe click |
| 240 | (-747,-637) | safe click |
| 360 | (-638,-685) | safe click |
| end | (-620,-764) | Lumbermill endpoint |

### LumbermillMinePath — Lumbermill → Mine · L≈284
Dir: из Lumbermill ↘SE · из Mine ←W · концы (-620,-764)→(-368,-824)

| offset | pos | note |
|---|---|---|
| 0 | (-620,-764) | Lumbermill side |
| 120 | (-513,-750) | safe click |
| 240 | (-409,-807) | approach Mine / junction |
| end | (-368,-824) | Mine endpoint |

### KnightRuinsMageTowerPath — KnightRuins → MageTower · L≈372
Dir: из KnightRuins ↙SW · из MageTower ↖NW · концы (-792,-288)→(-552,-268)

| offset | pos | note |
|---|---|---|
| 0 | (-792,-288) | KnightRuins side |
| 120 | (-767,-227) | safe click |
| 240 | (-661,-281) | safe click |
| 360 | (-559,-278) | approach MageTower / junction |
| end | (-552,-268) | MageTower endpoint |

### KnightRuinsEarthMagePath — MageTower → EarthMageCastle · L≈473
(узел в сцене всё ещё назван `KnightRuinsEarthMagePath`, но переразмечен на MageTower→EarthMage)
Dir: из MageTower ↖NW · из EarthMageCastle →E · концы (-552,-268)→(-432,-600)

| offset | pos | note |
|---|---|---|
| 0 | (-552,-268) | MageTower side |
| 120 | (-525,-355) | safe click |
| 240 | (-488,-456) | safe click |
| 360 | (-398,-526) | safe click |
| end | (-432,-600) | EarthMageCastle endpoint |

---

## Disabled / future / gated дороги — НЕ участвуют в выборе движения

- **VillageRuinsPath** (`Curve2D_village_ruins`), концы (-888,-504)↔(-792,-288).
  Фиолетовая, отключена: маршрут к Руинам теперь Dock→KnightRuins. Не в ROUTED_PAIRS.
- **EarthMageDarkCastlePath** (`Curve2D_earthmage_darkcastle`). Узел смещён (концы в
  ЛОКАЛЬНЫХ коорд (194,46)/(311,-44)). Фиолетовая, отключена. Не в ROUTED_PAIRS.
- **DarkCastle** 🔒 — `_is_locked` до `_mine_exit_done`. Ребро EarthMage→DarkCastle и
  ROAD_PATHS существуют, но навигация туда запрещена (gate). Не ломать gate.
- **Не-Path2D (ROAD_PATHS, direction-click туда НЕ ведёт)**: `EarthMageCastle→DarkCastle`,
  `EarthMageCastle→Mine`. До Mine реально дойти Path2D-цепочкой через Lumbermill.

---

## Узлы / перекрёстки

Все узлы совпадают с маркером локации (в пределах ~few px) — отдельной «технической»
точки в стороне от маркера нет. Поэтому **проход vs вход различается не точкой, а
намерением**: `_road_arrive_intended` = клик ≤`ARRIVAL_RADIUS`(60) от маркера →
вход; клик дальше/вбок → проход узла без захвата (`road_stop`).

| Узел (= маркер) | Сходятся road_id | Свернуть без входа |
|---|---|---|
| Village (-888,-504) | CastleVillagePath, VillageDockPath, VillageLumbermillPath (+disabled VillageRuins) | да: на узле кликни вдоль нужной дороги |
| Dock (-1160,-128) | VillageDockPath, DockKnightRuinsPath | да |
| KnightRuins (-792,-288) | DockKnightRuinsPath, KnightRuinsMageTowerPath (+disabled VillageRuins) | да |
| MageTower (-552,~-270) | KnightRuinsMageTowerPath, KnightRuinsEarthMagePath | да |
| Lumbermill (-624,-760) | VillageLumbermillPath, LumbermillMinePath | да |

Правило переключения (код): свернуть на ДРУГУЮ дорогу можно только когда герой в
пределах `JUNCTION_SWITCH_R`(50) от её кривой — т.е. фактически у узла, где кривые
сходятся (иначе диагональный срез). Локации рядом, но засасывать НЕ должны — это
обеспечивает `_road_arrive_intended` (см. фикс в Main.gd).

---

## Тестовые маршруты (road_id + offset sequence)

Клик в `pos` точки `safe click` ведёт герой шагами; финальный вход — клик в endpoint (≤60px).

| Маршрут | path(s) | offsets (→ pos) |
|---|---|---|
| Castle → Village | CastleVillagePath | 0(-1088,-720) → 240(-890,-601) → end(-888,-504) |
| Village → Dock | VillageDockPath | 0 → 240(-960,-381) → 480(-905,-213) → end(-1160,-128) |
| Dock → KnightRuins | DockKnightRuinsPath | 0 → 240(-935,-189) → end(-792,-288) |
| KnightRuins → MageTower | KnightRuinsMageTowerPath | 0 → 240(-661,-281) → end(-552,-268) |
| KnightRuins → EarthMageCastle | KnightRuinsMageTowerPath → KnightRuinsEarthMagePath | до MageTower (end), затем 0 → 240(-488,-456) → end(-432,-600). **Прямой дороги KR→EarthMage нет** |
| Village → Lumbermill | VillageLumbermillPath | 0 → 240(-747,-637) → end(-620,-764) |
| Lumbermill → Mine | LumbermillMinePath | 0 → 120(-513,-750) → end(-368,-824) |

Полный кольцевой прогон: Castle→Village→Dock→KnightRuins→MageTower→EarthMageCastle,
затем (через ROAD_PATHS/Lumbermill) к Mine и назад Lumbermill→Village.
