## `CLAUDE.md`

```md
# CLAUDE.md — Lost Kingdom

## О проекте

Lost Kingdom — 2D fantasy map-based игра на Godot 4.6.

Игрок выбирает героя в начале игры, затем перемещается по глобальной карте королевства.

Герой НЕ должен ходить свободно куда угодно. Герой перемещается только между фиксированными точками карты.

Основной игровой цикл:
1. Игрок выбирает открытую соседнюю локацию.
2. Герой идет по дороге к этой локации.
3. Запускается событие локации: бой, головоломка или поиск предметов.
4. Игрок получает награду.
5. Открываются новые соседние локации.
6. Карта постепенно раскрывается через туман войны.

## Движок

- Godot 4.6
- GDScript
- Главная сцена карты: `Main.tscn`
- Экран выбора героя: `HeroSelect.tscn`

## Главное правило по координатам

Никогда не угадывать координаты объектов на карте.

Единственный источник координат — `MAP_COORDINATES.md`.

Если нужно изменить положение точки:
1. Сначала получить точные X/Y из Godot.
2. Обновить `MAP_COORDINATES.md`.
3. Обновить координаты в `Main.gd`.
4. Не двигать точки “примерно”.

Если координаты визуально неправильные — не исправлять на глаз, а попросить пользователя дать точные координаты из Godot.

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