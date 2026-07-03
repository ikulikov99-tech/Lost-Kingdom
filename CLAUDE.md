# CLAUDE.md — Lost Kingdom

## О проекте

Lost Kingdom — 2D fantasy map-based игра на Godot 4.6 (GDScript).

Игрок выбирает героя, затем перемещается по глобальной карте королевства.
Герой НЕ ходит свободно — только между фиксированными точками по дорогам.

Основной игровой цикл:
1. Игрок выбирает открытую соседнюю локацию.
2. Герой идёт по дороге к ней.
3. Запускается событие локации: бой, головоломка или поиск предметов.
4. Игрок получает награду.
5. Открываются новые соседние локации.
6. Карта постепенно раскрывается через туман войны.

## Lost Kingdom MVP Canon

Until MVP release, do not change these decisions without explicit approval:

1. One playable heroine only.
2. Map scope is the existing 9-node kingdom graph; no procedural map generation.
3. First vertical slice uses Castle → Village → Lumbermill → Mine.
4. Map click means V2 road movement/discovery only.
5. Location enter is a separate explicit action, currently key E.
6. MVP combat direction is survivors-like / bullet-heaven burst encounters.
7. Road is content: ambushes, risk/reward events, fog pressure, rewards.
8. Do not expand into deckbuilder, tactical grid, open world, hero roster, or large RPG systems before MVP.

Полное обоснование (рынок, MVP-scope, арт, Steam-pitch) — `docs/GAME_DIRECTION_STRATEGY.md`.

## Движок и карта файлов

- Godot 4.6, GDScript. Главная сцена карты — `Main.tscn`, выбор героя — `HeroSelect.tscn`.
- `Main.gd` — вся карта: ввод, навигация (старая + V2), туман, UI, отрисовка. Большой файл.
- `Hero.gd` — герой: два режима движения (`follow_path2d` по PathFollow2D, `move_along_path` по массиву точек), сигнал `arrived(location_name)`.
- `FogOverlay.gd` + `fog*.gdshader` — туман войны (FBM-шейдер, trail, reveal).
- `GameState.gd` — глобальное состояние (autoload), `selected_hero`.
- `HeroSelect.gd`, `Splash.gd`, `MapDebugOverlay.gd` — выбор героя, сплеш, debug-оверлей.

## Архитектура навигации (junction ≠ location)

- **Junction** = узел дороги (Marker2D). Проезд через junction = **discover** (туман/«Найдено»), НЕ вход.
- **Location** = иконка. **Вход** только через icon-click → лог `[LOCATION_ENTER]` → `_run_location_action`.
- **Модель движения V2 = target-node** (как Slay-the-Spire): клик по зоне соседнего узла → герой идёт по ВСЕМУ ребру Path2D туда, анимированно, туман по пути. Один road-click = одно ребро.
  - Никакого угадывания направления по tangent/projection/dot — это было источником всех старых багов. Не возвращать.
  - Ключевые функции: `_v2_try_road_click` → `_v2_pick_target_junction` → `_v2_walk_segment` → `_v2_on_arrived` → `_v2_arrive_at_junction`. Имя движения `"_v2road_<target>"`, arrival ловится через `begins_with("_v2road_")`.
  - `discover` = `_discover_location` (туман/discovered/available/UI, без current_location, без action). `enter` = `_v2_enter_location`/`_run_location_action`.
- Схема и фазовый план — `docs/NAVIGATION_ARCHITECTURE.md`.

## Главное правило по координатам

Никогда не угадывать координаты объектов на карте.

Единственный источник координат — `MAP_COORDINATES.md`.

Если нужно изменить положение точки:
1. Сначала получить точные X/Y из Godot.
2. Обновить `MAP_COORDINATES.md`.
3. Обновить координаты в `Main.gd`.
4. Не двигать точки «примерно».

Если координаты визуально неправильные — не исправлять на глаз, а попросить у пользователя точные X/Y из Godot.

## Соглашения по коду

- **Только табы** для отступов (GDScript). Никаких пробелов в отступах.
- Намеренно неиспользуемый аргумент — с префиксом `_` (`_world_pos`, `_from_j`).
- Линт перед запуском в Godot (дешевле, чем гонять игру):
  ```
  gdlint Main.gd Hero.gd
  ```
  Конфиг — `gdlintrc` (стилевой шум отключён; чистый прогон = реально нет проблем).
- Быстрая проверка debug-лога — godot MCP (`run_project` + `get_debug_output`), а не скриншоты computer-use.

## Не трогать без явной просьбы

- `ROADBOOK.json` / `ROADBOOK.md` и старую карту — не редактировать, не добавлять в коммиты.
- Старую (fallback) навигацию и старые Path2D — не удалять.
- `git checkout` / `reset` — не делать без разрешения.
- Коммит/пуш — только по явному «да».

## Текущие координаты

```gdscript
const WAYPOINTS = {
	"Castle": {
		"title": "Королевский замок",
		"position": Vector2(-1112, -704)
	},
	"Village": {
		"title": "Деревня",
		"position": Vector2(-928, -504)
	},
	"Dock": {
		"title": "Пристань",
		"position": Vector2(-1160, -128)
	},
	"KnightRuins": {
		"title": "Руины рыцарей",
		"position": Vector2(-648, -288)
	},
	"MageTower": {
		"title": "Башня мага",
		"position": Vector2(-560, -320)
	},
	"EarthMageCastle": {
		"title": "Замок мага земли",
		"position": Vector2(-464, -488)
	},
	"DarkCastle": {
		"title": "Замок тьмы",
		"position": Vector2(-376, -568)
	},
	"Lumbermill": {
		"title": "Лесопилка",
		"position": Vector2(-640, -752)
	},
	"Mine": {
		"title": "Заброшенная шахта",
		"position": Vector2(-392, -832)
	}
}

const WAYPOINT_CONNECTIONS = {
	"Castle": ["Village"],
	"Village": ["Castle", "Dock", "KnightRuins", "Lumbermill"],
	"Dock": ["Village"],
	"KnightRuins": ["Village", "MageTower", "EarthMageCastle"],
	"MageTower": ["KnightRuins"],
	"EarthMageCastle": ["KnightRuins", "DarkCastle", "Mine"],
	"DarkCastle": ["EarthMageCastle"],
	"Lumbermill": ["Village", "Mine"],
	"Mine": ["Lumbermill", "EarthMageCastle"]
}
```
