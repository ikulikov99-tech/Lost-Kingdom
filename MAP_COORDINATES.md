# MAP_COORDINATES.md — Lost Kingdom

Координаты для Main.gd (WorldMap at position 0,0, Camera zoom 0.76).
**ВНИМАНИЕ**: эти координаты приблизительные — нужно уточнить в редакторе Godot.
Если двигаешь точку — обнови этот файл и `Main.gd`.

| Локация   |   X |   Y | Описание           |
|-----------|----:|----:|--------------------|
| Castle    | -590 | -240 | Ворота замка       |
| Village   | -435 |  -20 | Деревня            |
| Mine      |  -35 | -315 | Шахта/лесопилка    |
| Ruins     | -330 |  125 | Развалины          |
| MageTower |    0 |  285 | Башня мага         |

## Маршруты
- Castle → Village
- Village → Castle, Mine, Ruins
- Mine → Village
- Ruins → Village, MageTower
- MageTower → Ruins

## Как измерить точно
1. Открой Main.tscn в редакторе
2. Создай временный Node2D, перетащи на нужное место
3. Запиши Position из Инспектора
4. Обнови этот файл и Main.gd
