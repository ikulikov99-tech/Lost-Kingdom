# Lost Kingdom — Project Backup
> Обновляется после каждой завершённой задачи.
> Последнее обновление: 2026-06-12 (фикс развилок: смена ветки + реверс)

## Later / Tools
Когда начнём сложные системы — события на дорогах, квесты, подземелье, бои,
сохранения, QA — рассмотреть установку **Obra Superpowers** для Claude Code /
Codex. Сейчас НЕ устанавливать: фокус — дороги, туман, карта и минимальные
правки. Superpowers помогает с методологией и чеклистами, но не обязательно
экономит токены.

---

## Стек и окружение

| | |
|---|---|
| Движок | Godot 4.6 (GDScript) |
| Платформа | Windows 11, NVIDIA GeForce MX250 |
| Активная ветка | `feature/map-navigation-camera-fog` |
| PR | [#2](https://github.com/ikulikov99-tech/Lost-Kingdom/pull/2) — map navigation + camera + fog |
| Репозиторий | https://github.com/ikulikov99-tech/Lost-Kingdom |

---

## Важные файлы

| Файл | Назначение |
|---|---|
| `Main.gd` | Главный контроллер карты: ввод, движение, туман, UI |
| `Main.tscn` | Сцена карты: Hero, Path2D узлы, Camera2D, FogOverlay |
| `Hero.gd` | Движение героя по массиву точек, сигнал `arrived` |
| `FogOverlay.gd` | Управление ShaderMaterial: reveal, trail, camera sync |
| `fog.gdshader` | GLSL шейдер тумана войны (fullscreen, screen-space) |
| `GameState.gd` | AutoLoad: selected_hero, current_location, unlocked_locations |
| `MAP_COORDINATES.md` | Единственный источник координат локаций — не менять |
| `PROJECT_BACKUP.md` | Этот файл |
| `AI_HANDOFF.txt` | Краткая сводка для передачи контекста |

---

## Архитектура сцены

```
Main (Node2D) ← Main.gd
├── WorldMap (Sprite2D)               position=(-687, -547)
├── CastleVillagePath (Path2D)        15 pts
├── VillageDockPath (Path2D)          23 pts  (кривые подогнаны вручную)
├── VillageRuinsPath (Path2D)         17 pts  (кривые подогнаны вручную)
├── VillageLumbermillPath (Path2D)    4 pts
├── KnightRuinsMageTowerPath (Path2D) 3 pts
├── KnightRuinsEarthMagePath (Path2D) 4 pts
├── Hero (CharacterBody2D) ← Hero.gd
│   ├── AnimatedSprite2D   scale=(0.45, 0.45)
│   ├── CollisionShape2D   size=(28, 40)
│   └── Camera2D           zoom=(1.3, 1.3)
│       limits: left=-1523, right=149, top=-1017, bottom=-77
└── UI (CanvasLayer)
    ├── FogOverlay (ColorRect) ← FogOverlay.gd  [MOUSE_FILTER_IGNORE]
    ├── StatusPanel/CurrentLabel
    ├── StatusPanel/UnlockedLabel
    └── TooltipLabel
```

**AutoLoad:** `GameState` (singleton) — хранит состояние между сценами.

---

## Координаты локаций (ТОЛЬКО из MAP_COORDINATES.md)

| ID | Название | Позиция |
|---|---|---|
| Castle | Королевский замок | (-1112, -704) |
| Village | Деревня | (-928, -504) |
| Dock | Пристань | (-1160, -128) |
| KnightRuins | Руины рыцарей | (-648, -288) |
| MageTower | Башня мага | (-560, -320) |
| EarthMageCastle | Замок мага земли | (-464, -488) |
| DarkCastle | Замок тьмы | (-376, -568) |
| Lumbermill | Лесопилка | (-640, -752) |
| Mine | Заброшенная шахта | (-392, -832) |

**Правило:** никогда не угадывать координаты. Всегда читать MAP_COORDINATES.md.

---

## Граф маршрутов

```
Castle       ↔ Village
Village      ↔ Castle, Dock, KnightRuins, Lumbermill
Dock         ↔ Village
KnightRuins  ↔ Village, MageTower, EarthMageCastle
MageTower    ↔ KnightRuins
EarthMageCastle ↔ KnightRuins, DarkCastle, Mine
DarkCastle   ↔ EarthMageCastle
Lumbermill   ↔ Village, Mine
Mine         ↔ Lumbermill, EarthMageCastle
```

---

## Реализованные системы

### Туман войны (гибридная система: текстуры + маска)

Структура внутри `UI/FogOverlay` (SubViewportContainer ← FogOverlay.gd):
```
FogViewport (SubViewport, transparent_bg)
├── FogBase (ColorRect)    ← fog_base.gdshader: fog_density.png ×2 масштаба, дрейф
├── Clouds (Node2D)        ← 8 рисованных puff Sprite2D (3 слоя: 1.2x/1.8x/2.5x)
└── RevealMask (ColorRect) ← fog_mask.gdshader (blend_mul): маска видимости
```

- Маска умножает альфу всего под ней: 1 = туман остаётся, 0 = открыто
- Вся reveal-логика (rp*, tp*, hero) — только в fog_mask.gdshader
- Края рвёт текстура `fog/fog_edge_mask.png` (edge_amp = 48px)
- Puff-облака: world-anchored дрейф с wrap по зоне карты, спавн из кода (seed фиксирован)
- Облачные слои ничего не знают про reveal — независимы
- Ассеты: `fog/cloud_puff_1..6.png`, `fog/fog_density.png`, `fog/fog_edge_mask.png`
- `fog.gdshader` (FBM-версия) оставлен в репо как fallback, не используется
- Два вида раскрытия: постоянное (discovered-локации) и временное (герой + trail)
- Trail: FIFO 8 точек, шаг 110px, очищается при прибытии в локацию

**Параметры маски (fog_mask.gdshader):**
```glsl
reveal_r    = 135.0   // радиус постоянного раскрытия (локации + trail)
edge_soft   = 18.0    // мягкость края
hero_reveal_r = 90.0  // радиус вокруг героя (был 160, -44% для исследования)
edge_amp      = 75.0  // амплитуда рваных краёв у локаций (px)
edge_amp_hero = 30.0  // у героя, пропорционально радиусу
```
В Main.gd зеркально: `HERO_VISIBLE_R = 90` (герой), `ROAD_VISIBLE_R = 160` (локации).

### Маршруты через Path2D (6 из 9)

| Маршрут | Точек |
|---|---|
| Castle↔Village | 15 |
| Village↔Dock | 23 |
| Village↔KnightRuins | 17 |
| Village↔Lumbermill | 4 |
| KnightRuins↔MageTower | 3 |
| KnightRuins↔EarthMageCastle | 4 |

Оставшиеся 3 маршрута в `ROAD_PATHS` (промежуточные точки-массивы):
- EarthMageCastle↔DarkCastle
- EarthMageCastle↔Mine
- Lumbermill↔Mine

### Механика клика по дороге (Итерация 1 — все Path2D-дороги)

- Работает для любой из 6 Path2D-дорог (не только Castle↔Village)
- Клик ≤35px от кривой → герой идёт до точки клика (не до локации)
- В развилке (напр. Village с 4 дорогами) выбирается ближайшая к клику дорога
- Остановка на дороге: туман раскрывается, счётчик не меняется, ждёт след. клик
- Движение только вперёд к dest (назад по дороге нельзя)
- При приближении к dest ≤60px — локация открывается автоматически
- Скрытые (не available) локации напрямую кликнуть нельзя
- Fallback: клик по иконке локации — для ROAD_PATHS-маршрутов и обратного пути

**Защита целостности исследования (итерация 2):**
- Слепой icon-click сквозь туман на неоткрытую Path2D-локацию заблокирован
  (иконка кликабельна только если точка видима); ROAD_PATHS-маршруты
  (EarthMageCastle↔DarkCastle/Mine, Lumbermill↔Mine) icon-click сохраняют —
  иначе тупик
- Посреди дороги принимаются только клики по самой дороге (icon-fallback
  строил путь от исходной локации → телепорт-возврат)
- Реверс по дороге работает из локации (fwd=false), посреди дороги — только вперёд

**Развилки и реверс (фикс):** игрок НЕ заперт на текущей дороге.
Каждый клик заново оценивает ВСЕ дороги `current_location` от фактической
позиции героя; направление и dest вычисляются по клику (к соседу или назад
к `current_location`). Смена ветки — через общий узел: дойти назад к узлу,
затем выбрать другую ветку. `current_location` = узел-развилка (последняя
посещённая локация, не меняется пока герой на дороге).

**Состояние дороги:**
```gdscript
_road_active: bool   // герой стоит на дороге, не в локации (для icon-блока)
_road_path:   Path2D // активная Path2D (для пересчёта offset при прибытии)
_road_dest:   String // пункт назначения текущего шага (сосед или назад)
_road_offset: float  // смещение героя на последней остановке
```

**Ключевые методы Main.gd:**
```gdscript
_route_path_for(a, b)                  // Path2D для пары локаций (dict)
_try_road_click(world_pos)             // оценка всех дорог узла, ближайшая принявшая
_start_road_move(path, nbr, world_pos) // движение к клику; dest по направлению клика
_build_partial_path(path, from, to)    // частичный путь (любое направление)
_is_road_point_visible(point)          // проверка видимости (зеркало шейдера)
_on_hero_arrived(name)                 // диспетчер: "_road_" vs локация
_arrive_at_location(name)              // открывает локацию, сброс _road_*
```

**Константы:**
```gdscript
TRAIL_STEP      = 110.0  // шаг trail-точек (px)
ROAD_CLICK_DIST = 35.0   // радиус попадания клика на дорогу
ROAD_VISIBLE_R  = 160.0  // радиус видимости для клика (GDScript, ≠ shader reveal_r)
ARRIVAL_RADIUS  = 60.0   // автоприбытие в локацию с дороги
```

### Состояние и UI

- `discovered` — туман открыт, считается в счётчике
- `available` — кликабельные соседи, туман не открыт
- Названия локаций показываются только для `discovered`
- Tooltip при наведении на любую discovered/available локацию

---

## Принятые решения

| Решение | Причина |
|---|---|
| Shader в CanvasLayer, не в World | Туман в screen-space, камера может двигаться свободно |
| `get_screen_center_position()` | Учитывает limits Camera2D в отличие от `global_position` |
| Trail FIFO 8 точек | Надёжное покрытие при hero_reveal_r=160, минимум uniforms |
| `"_road_cv_"` как маркер destination | Различает road-stop от location-arrival без изменения Hero.gd |
| `ROAD_VISIBLE_R` отдельно от `reveal_r` | Игровая логика независима от визуальных параметров шейдера |
| Fallback система переходов сохранена | Новая механика проверяется безопасно, не ломает MVP |

---

## Известные баги (отложены)

| Баг | Описание | Где фиксить | Приоритет |
|---|---|---|---|
| Герой идёт задом | На маршруте Village→Castle `flip_h` не реагирует на `velocity.x` | Hero.gd | После маршрутов |

---

## Ограничения (CLAUDE.md — нельзя нарушать)

- Не угадывать координаты — только из MAP_COORDINATES.md
- Не менять карту (world_map.png)
- Не удалять HeroSelect
- Не переделывать весь проект с нуля
- Не добавлять: магазин, рекламу, Supabase, Cloudinary, мультиплеер

---

## Активные задачи

- [ ] **Визуал тумана** — заменить плоскую маску на FBM-облачный туман (только `fog.gdshader` + минимально `FogOverlay.gd`)
- [ ] Перевести 3 оставшихся маршрута на Path2D (EarthMageCastle↔DarkCastle/Mine, Lumbermill↔Mine)
- [ ] Road-click обратного направления (сейчас только вперёд к dest)
- [ ] Исправить flip_h героя на обратных маршрутах (Hero.gd)
- [ ] (позже) события на дорогах: засады, квесты, находки

---

## Концепция (design, не реализовано): события на дорогах + захват точек

> Зафиксировано 2026-06-21. Цель — герой не идёт быстро от локации к локации,
> а исследует дорогу шагами (уже реализовано direction-click'ом), и в пути
> может столкнуться с засадой/ловушкой или захватить мелкую точку дохода.
> Туман за пройденным участком пока не возвращается (MVP), но концепция
> допускает возврат тумана позже, если на участке появится новая угроза —
> отложено, не в первой итерации.

### Засады / ловушки на дороге (ROAD_EVENTS)

- НЕ случайны — привязаны к заранее расставленным точкам на конкретной
  Path2D-дороге (offset на кривой), как сейчас Marker2D для waypoint'ов.
  Координаты/offset — только из Godot, не на глаз (правило CLAUDE.md).
- Триггер смешанный: часть событий — диалог с выбором ("На вас напали.
  Принять бой?" / "Вы попали в ловушку. Пройти квест?", Да/Нет; при "Нет"
  герой отступает назад по дороге, точка остаётся активной для след. раза).
  Часть событий — без выбора, срабатывают форсом при подходе к точке.
- При срабатывании — переход в ОТДЕЛЬНУЮ сцену (мини-подземелье / мини-карта),
  не оверлей на Main.tscn. По завершении — возврат в Main.tscn на сохранённую
  позицию героя.
- После успешного прохождения — точка очищается НАВСЕГДА (решение для MVP,
  без respawn/таймеров — проще и надёжнее).

Набросок данных (Main.gd, пока не реализовано):
```gdscript
const ROAD_EVENTS := {
	"ambush_dock_1": {
		"road": "VillageDockPath",   # имя Path2D-узла
		"offset": 0.0,                # offset на кривой — взять из Godot, не угадывать
		"optional": true,             # true = диалог Да/Нет, false = форс-вход
		"scene": "res://dungeons/Ambush1.tscn",
	},
}
```

### Захват точек дохода (CAPTURE_POINTS)

- Отдельный тип сущности, НЕ входит в 9 текущих WAYPOINTS/ROUTED_PAIRS —
  мелкие точки вдоль дороги со своей иконкой.
- Захват — герой подошёл и кликнул (мгновенно, без боя/квеста — MVP).
- Дают пользователю доход/бонусы для апгрейда (валюта/ресурс — с нуля,
  в GameState пока ничего подобного нет).

Набросок данных (пока не реализовано):
```gdscript
const CAPTURE_POINTS := {
	"outpost_1": {
		"title": "Сторожевой пост",
		"position": Vector2.ZERO,    # из Marker2D в Godot, не угадывать
		"reward": {"gold": 10},
	},
}
```

### Расширение GameState.gd (пока не реализовано)

```gdscript
var cleared_events: Array[String] = []     # ROAD_EVENTS, пройденные навсегда
var captured_points: Array[String] = []    # CAPTURE_POINTS, захваченные
var resources: Dictionary = {"gold": 0}    # валюта/ресурсы для апгрейдов
```

### Интеграция с навигацией

Триггер встраивается в существующий direction-click шаг (`_commit_road_move`
в незакоммиченных правках Main.gd): перед завершением шага по дороге
проверяем, не пересекает ли путь героя offset из `ROAD_EVENTS` для активной
Path2D. Локационные события (Village, KnightRuins и т.д.) — как и раньше,
отдельная сцена при первом прибытии, не оверлей.

### Не решено / отложено

- Конкретный список засад/ловушек по дорогам и их типы (квест vs бой)
- Что именно дают точки захвата кроме gold (апгрейды героя?)
- Возврат тумана при появлении новой угрозы на пройденном участке
