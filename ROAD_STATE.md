# Lost Kingdom — Road State
> Снимок состояния дорог/навигации. Обновлять при изменении маршрутов.
> Последнее обновление: 2026-06-12

---

## Граф маршрутов (ROUTES, Main.gd)

```
Castle      ↔ Village
Village     ↔ Castle, Dock, Lumbermill
Dock        ↔ Village, KnightRuins
KnightRuins ↔ Dock, MageTower, EarthMageCastle
MageTower   ↔ KnightRuins              (тупик by design)
EarthMageCastle ↔ KnightRuins, DarkCastle, Mine
DarkCastle  ↔ EarthMageCastle          (тупик by design)
Lumbermill  ↔ Village, Mine
Mine        ↔ Lumbermill, EarthMageCastle
```

Путь к Руинам теперь: **Castle → Village → Dock → KnightRuins** (не через Деревню напрямую).

---

## Активные Path2D (используются road-click логикой)

| Узел Path2D | Маршрут | Привязка в коде |
|---|---|---|
| CastleVillagePath | Castle ↔ Village | `_cv_path` |
| VillageDockPath | Village ↔ Dock | `_vd_path` |
| DockKnightRuinsPath | Dock ↔ KnightRuins | `_dk_path` (новый, identity-узел) |
| VillageLumbermillPath | Village ↔ Lumbermill | `_vl_path` |
| LumbermillMinePath | Lumbermill ↔ Mine | `_lm_path` (подключён: ключ Lumbermill-Mine) |
| KnightRuinsMageTowerPath | KnightRuins ↔ MageTower | `_km_path` |
| KnightRuinsEarthMagePath | KnightRuins ↔ EarthMageCastle | `_ke_path` |

Подключение Path2D к паре локаций — в `_route_path_for()` и `ROUTED_PAIRS`.
Выбор дороги при клике — по фактической близости героя к кривой (не по
current_location), поэтому у развилки доступны все ветки.

---

## Отключённые / неиспользуемые Path2D

| Узел | Статус |
|---|---|
| VillageRuinsPath | Оставлен в сцене (ручные точки целы), но **отключён** от логики: убран из ROUTES / `_route_path_for` / `_draw_roads`; переменная `_vr_path` удалена. Маршрут к Руинам теперь Dock→KnightRuins. |
| EarthMageDarkCastlePath | Черновик. **Не подключать** — это будущий путь от выхода из подземелья к Замку Тьмы, НЕ обычная дорога EarthMageCastle→DarkCastle. |

Маршруты без Path2D (работают через ROAD_PATHS-массивы / icon-fallback):
EarthMageCastle↔DarkCastle, EarthMageCastle↔Mine.

---

## Waypoints (точка прихода героя, WAYPOINTS в Main.gd)

| Локация | Waypoint |
|---|---|
| Castle | (-1112, -704) |
| Village | (-928, -504) |
| Dock | (-1160, -128) |
| KnightRuins | (-816, -296) ← вход с дороги Dock→Ruins (был центр -648,-288) |
| MageTower | (-560, -320) |
| EarthMageCastle | (-464, -488) |
| DarkCastle | (-376, -568) |
| Lumbermill | (-640, -752) |
| Mine | (-392, -832) |

Waypoint = точка движения/прибытия героя. **Не двигать обратно.**

---

## Reveal centers (центр раскрытия тумана, REVEAL_CENTERS в Main.gd)

Заданы только там, где waypoint стоит на входе с дороги, а не в центре картинки.
Для остальных локаций reveal = waypoint.

| Локация | Reveal center |
|---|---|
| Dock | (-1250, -145) |
| KnightRuins | (-700, -330) |
| MageTower | (-530, -265) |
| EarthMageCastle | (-600, -600) |
| Lumbermill | (-615, -795) |

Центры смещены к зданиям/табличкам (waypoints стоят на въездах, а постройки
смещены на карте). EarthMage — на замок и ~226px от DarkCastle (прячет его).
Известное ограничение: единый reveal_r~135 не всегда полностью кроет крупную
постройку+табличку; полное покрытие требует per-location reveal radius
(правка FogOverlay/шейдера — НЕ цвет) — ждёт подтверждения.

`_reveal_pos(id)` = REVEAL_CENTERS если задан, иначе waypoint.
`_arrive_at_location`, стартовый Castle-reveal и `_is_road_point_visible` используют reveal-центр.
Лимит шейдера — 9 reveal-точек (по одной на локацию), не превышать.

---

## Ключевые константы road-click (Main.gd)

```
ROAD_CLICK_DIST = 50    # макс. расстояние клика до кривой
HERO_VISIBLE_R  = 110   # видимая кромка вокруг героя (= радиус 80 + шум 30)
ROAD_VISIBLE_R  = 210   # видимая кромка вокруг открытых локаций (135 + 75)
ARRIVAL_RADIUS  = 60    # дистанция до waypoint для прибытия
```
Туман-гейт клика применяется ТОЛЬКО к неоткрытым пунктам назначения.
Дорога между двумя discovered-локациями кликается на всю длину.

---

## Осталось сделать

- [ ] Reveal-центры — оценка по карте; уточнить визуально, если какая-то локация всё ещё раскрывается не полностью.
- [ ] flip_h героя на обратных маршрутах (Hero.gd) — отложено.
- [ ] Перевести оставшиеся маршруты на Path2D: EarthMageCastle↔DarkCastle, EarthMageCastle↔Mine (кривые рисует пользователь).
- [ ] Синхронизировать старты этих Path2D с waypoints после отрисовки.

---

## Не трогать

- Hero.gd (откатан, белый прямоугольник убран).
- Туман по цвету; UI; ROUTES без явной задачи.
- EarthMageDarkCastlePath и всё про подземелье / путь к Замку Тьмы.
- Карту world_map.png.
- Waypoints не двигать обратно к старым центрам.
- Новые большие механики (события, квесты, бои) — только после отчёта.
