# Lost Kingdom — Project Backup
> Обновляется после каждой завершённой задачи.
> Последнее обновление: 2026-06-11 (FBM fog)

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

### Туман войны

- Fullscreen GLSL shader на ColorRect в CanvasLayer (screen-space)
- Конвертирует SCREEN_UV → мировые координаты через `cam_pos + screen_px / cam_zoom`
- `camera.get_screen_center_position()` — учитывает zoom и limits Camera2D
- Два вида раскрытия: постоянное (discovered-локации) и временное (герой + trail)
- Trail: FIFO 8 точек, шаг 110px, очищается при прибытии в локацию

**Текущие параметры шейдера:**
```glsl
reveal_r    = 135.0   // радиус постоянного раскрытия (локации + trail)
edge_soft   = 18.0    // мягкость края
hero_reveal_r = 160.0 // радиус раскрытия вокруг героя (не меняет счётчик)
fog_color   = vec4(0.08, 0.10, 0.16, 0.98)
```

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

### Механика клика по дороге (Шаг 1 — только Castle↔Village)

- Клик ≤35px от кривой → герой идёт до точки клика (не до локации)
- Остановка на дороге: туман раскрывается вокруг героя, счётчик не меняется
- При приближении к Village ≤60px — Village открывается автоматически
- `_cv_offset: float` — позиция вдоль кривой (0 = Castle, max = Village)
- Fallback: клик по иконке локации работает для всех остальных дорог

**Ключевые методы Main.gd:**
```gdscript
_try_road_click_cv(world_pos)          // обрабатывает клик по дороге
_build_partial_cv_path(from_off, to_off) // строит частичный путь
_is_road_point_visible(point)          // проверяет видимость (зеркало шейдера)
_on_hero_arrived(name)                 // диспетчер: "_road_cv_" vs локация
_arrive_at_location(name)              // открывает локацию, сбрасывает _cv_offset
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
- [ ] Road-click механика для остальных дорог (Шаг 2+)
- [ ] Перевести 3 оставшихся маршрута на Path2D
- [ ] Исправить flip_h героя на обратных маршрутах (Hero.gd)
