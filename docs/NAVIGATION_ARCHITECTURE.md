# Архитектура навигации Lost Kingdom — «дорога как контент»

> Документ-схема. Только дизайн и план. Код не меняется.
> Дата: 2026-06-24

---

## Идея геймплея

- Герой **не едет сразу** к локации — идёт по дороге постепенно.
- Туман открывается **вокруг героя** по мере движения.
- На дороге — засады, квесты, награды, случайные события.
- В самих локациях — отдельный бой / квест / меню.
- Вход в локацию **только icon-click**.
- road-click **не запускает** `LOCATION_ENTER`.
- В этом — страх и таинственность пути.

---

## 0. Ключевой принцип

Разделяем **две сущности**, которые сейчас слиты в одну:

```
◆ JUNCTION (road node)          ◉ LOCATION (icon)
  — точка/развилка на дороге      — деревня, руины, башня, шахта
  — герой ПРОЕЗЖАЕТ сквозь        — герой ВХОДИТ только icon-click
  — НЕ запускает LOCATION_ENTER   — запускает _run_location_action
  — несёт fog-reveal + encounters — несёт бой/квест/меню
```

Дорога = ребро между двумя **junction**. Локация висит на коротком **spur**
(отростке) от своего junction. Проезд junction'а ничего не запускает —
это и убирает «засасывание» в локацию.

---

## 1. ASCII-схема карты (схематично, не в масштабе)

Реальная топология — **кольцо** вокруг центральных руин + 2 отростка
(Castle, DarkCastle). Координаты — в таблице раздела 2.

```
        ◉Castle                 ◉Lumbermill ════════════════ ◉Mine
           ╲                      ╱  ◆Lj                 ◆Mj   ║
          ◆Cj                    ╱                              ║
             ╲                  ╱                               ║  (правая
              ◆Vj──◉Village════╝                                ║   сторона
             ╱    ╲                                             ║   кольца /
            ╱      ╲                                   ◉EarthMage║   main-road)
         ◆Dj        ╲                                 ◆Ej═══════╝
         ◉Dock       ╲                                 ║  ╲
            ╲         ╲                                ║   ◉DarkCastle ⊘ locked
             ╲         ╲                    ◉MageTower ║
              ╲         ◆KRj──◉KnightRuins  ◆MTj══════╝
               ╲═══════╝         ╲          ╱
                (Dock──KnightRuins)╲════════╝ (KnightRuins──MageTower)

  ◆ = junction (на дороге)    ◉ = location icon (вход icon-click)
  ═══ / ╲ ╱ │ = road segment (Path2D)    ⊘ = locked/future
  ──◉ от ◆ = короткий spur к иконке локации
```

Кольцо (по часовой от Village):
**Village → Lumbermill → Mine → EarthMage → MageTower → KnightRuins → Dock → Village**.
Отростки: **Castle** (от Village), **DarkCastle** (от EarthMage, locked).

---

## 2. Junction-узлы (дорожные точки)

Ставятся **на дорогу**, рядом с локацией, но НЕ в её иконке.
Координата junction ≈ точка, где сейчас стоит WAYPOINT локации (вход с дороги);
иконку локации сдвигаем на здание.

| Junction               | ≈ позиция (от WAYPOINT) | роль                                  |
|------------------------|-------------------------|---------------------------------------|
| `CastleJunction`       | (-1112, -704)           | конец отростка, старт игры             |
| `VillageJunction`      | (-928, -504)            | **хаб**: Castle / Dock / Lumbermill    |
| `DockJunction`         | (-1160, -128)           | угол кольца (низ-запад)                |
| `KnightRuinsJunction`  | (-792, -288)            | кольцо                                 |
| `MageTowerJunction`    | (-560, -320)            | кольцо                                 |
| `EarthMageJunction`    | (-464, -488)            | развилка: Mine / DarkCastle / MageTower|
| `LumbermillJunction`   | (-640, -752)            | кольцо (верх)                          |
| `MineJunction`         | (-392, -832)            | кольцо (верх-восток)                   |
| `DarkCastleJunction`   | (-376, -568)            | конец отростка (locked)                |

Реализация: `Marker2D` под отдельным узлом сцены, напр. `RoadGraph/Junctions/…`.
Координаты junction = координаты curve-точек, где дороги сходятся.

---

## 3. Location-иконки (вход только icon-click)

| Location                  | spur от junction      | действие при icon-click   |
|---------------------------|-----------------------|---------------------------|
| `CastleLocation`          | CastleJunction        | стартовое меню / квест    |
| `VillageLocation`         | VillageJunction       | торговля / квест          |
| `DockLocation`            | DockJunction          | лодка / событие           |
| `KnightRuinsLocation`     | KnightRuinsJunction   | бой / лут                 |
| `MageTowerLocation`       | MageTowerJunction     | маг-квест                 |
| `EarthMageCastleLocation` | EarthMageJunction     | босс / сюжет              |
| `LumbermillLocation`      | LumbermillJunction    | ресурс / квест            |
| `MineLocation`            | MineJunction          | бой / ресурс              |
| `DarkCastleLocation`      | DarkCastleJunction    | финал (locked)            |

Иконка = кликабельный `Area2D`/`Sprite2D`, отдельный от junction.
Клик по иконке → `_run_location_action(id)`. Клик по дороге рядом —
**никогда** не вызывает action.

---

## 4. Road-сегменты (рёбра между junction)

Каждый сегмент = один Path2D (или участок) с длиной (`baked_length`) и `offset` —
на это вешаются encounters.

| #  | Segment (ребро)                       | примечание                       |
|----|---------------------------------------|----------------------------------|
| 1  | `CastleJunction ── VillageJunction`   | стартовый отрезок (отросток)     |
| 2  | `VillageJunction ── DockJunction`     | кольцо                           |
| 3  | `VillageJunction ── LumbermillJunction`| кольцо                          |
| 4  | `LumbermillJunction ── MineJunction`  | кольцо (верх)                    |
| 5  | `MineJunction ── EarthMageJunction`   | кольцо / **main-road** правая сторона |
| 6  | `EarthMageJunction ── MageTowerJunction`| кольцо                         |
| 7  | `MageTowerJunction ── KnightRuinsJunction`| кольцо                       |
| 8  | `KnightRuinsJunction ── DockJunction` | кольцо (замыкает)                |
| 9  | `EarthMageJunction ── DarkCastleJunction`| **locked/future** отросток    |

Spur-связи (junction → своя иконка, очень короткие, не для encounters):
`VillageJunction→VillageLocation`, `DockJunction→DockLocation`,
`KnightRuinsJunction→KnightRuinsLocation`, `LumbermillJunction→LumbermillLocation`, и т.д.

Adjacency (для шага / выбора соседнего сегмента у развилки):

```
Castle:     [Village]
Village:    [Castle, Dock, Lumbermill]
Dock:       [Village, KnightRuins]
KnightRuins:[Dock, MageTower]
MageTower:  [KnightRuins, EarthMage]
EarthMage:  [MageTower, Mine, DarkCastle⊘]
Mine:       [EarthMage, Lumbermill]
Lumbermill: [Village, Mine]
DarkCastle: [EarthMage] ⊘
```

(Совпадает с текущим `ROUTES` — данные уже есть, нужно лишь переосмыслить
узлы как junction.)

---

## 5. Road-encounters (формат: segment + offset)

Encounter привязан к **ребру и offset**, не к локации. Триггер: когда
`_road_offset` героя пересекает отметку (с учётом направления).

```
# segment                            offset   event                one_shot
VillageJunction-LumbermillJunction     320     bandit_ambush         true
VillageJunction-LumbermillJunction     180     travelling_merchant   false
LumbermillJunction-MineJunction        260     reward_cache          true
MineJunction-EarthMageJunction         400     elite_ambush          true
EarthMageJunction-MageTowerJunction    150     road_quest_giver      true
KnightRuinsJunction-DockJunction       220     random_event          false
VillageJunction-DockJunction           140     toll_bridge           false
```

Типы:
- `bandit_ambush` / `elite_ambush` — бой
- `travelling_merchant` / `reward_cache` — награда
- `road_quest_giver` — квест
- `random_event` — выбор
- `toll_bridge` — плата

Хранить как ресурс/словарь `ENCOUNTERS[segment_key] = [{offset, event, one_shot}]`.

Это и есть «страх и таинственность»: туман открыл кусок дороги → герой
шагнул → на offset 320 сработала засада. Локация ещё не достигнута,
а на пути уже контент.

---

## 6. Как работает клик (правила)

```
road-click ПО ДОРОГЕ (далеко от junction):
   → герой делает ШАГ по текущему сегменту в сторону клика
   → open fog вокруг героя, trail-reveal
   → проверка encounter по новому offset
   → НЕ вызывает LOCATION_ENTER

click РЯДОМ С JUNCTION (в радиусе развилки):
   → можно выбрать соседний сегмент (по adjacency)
   → переключение на другой Path2D у точки схода кривых
   → проезд junction'а сам по себе ничего не запускает

icon-click ПО ЛОКАЦИИ:
   → ЕДИНСТВЕННЫЙ путь к _run_location_action(id)
   → бой / квест / меню локации

проезд junction:
   → reach-node (discover/fog), но БЕЗ action
```

Движение остаётся **пошаговым** (фишка «иду в неизвестность»). A* пока НЕ нужен —
достаточно adjacency, чтобы знать соседние сегменты у развилки.

---

## 7. Что из текущего кода СОХРАНЯЕТСЯ

- **Path2D / Curve2D** — становятся рёбрами графа (визуал + линейка offset
  под encounters). Главное достояние, ничего не выбрасываем.
- **fog reveal** — без изменений, привязан к позиции героя.
- **trail reveal** — без изменений.
- **icon-click separation** — уже есть, становится единственным входом в локацию.
- **`_reach_location_node` / `_run_location_action`** — разделение остаётся;
  reach на junction, action только icon-click.
- **offset-movement (`_commit_road_move`, `_build_partial_path`)** — ядро шага
  по сегменту, переиспользуется.
- **Задел под encounter-триггер по offset** — ложится идеально.

---

## 8. Что потом УБИРАЕТСЯ / упрощается

- **through-road boarding (`_try_through_road`, `THROUGH_ROUTES`)** — не нужен:
  главная дорога становится обычной цепочкой рёбер через junction.
- **`dest_is_current_location` костыли + `force_current_location_candidates`** —
  исчезают: проезд развязки ≠ вход, конфликта нет.
- **dot/candidate guessing (цикл `for pair in ROUTED_PAIRS` с подбором по dot)** —
  упрощается до «выбрать соседний сегмент у junction».
- **засасывание в location endpoints** — исчезает по построению: иконка отделена
  от дороги spur'ом.
- **fast-path ROAD_CONTINUE / REVERSE / SKIP-ветки** — большая часть схлопывается:
  продолжение по сегменту тривиально, реверс = шаг к другому концу того же ребра.

---

## 9. План внедрения по фазам

### Phase 1 — только схема + junction markers (нулевой риск)
- Добавить `Marker2D` junction-узлы в сцену (RoadGraph/Junctions), иконки локаций
  оставить как есть.
- Описать данные графа: `JUNCTIONS`, `SEGMENTS` (ребро→Path2D), `ADJACENCY`
  (= нынешний `ROUTES`).
- Навигацию НЕ переключать. Только данные + визуальная проверка, что junction'ы
  стоят на дорогах.

### Phase 2 — один тестовый маршрут Castle → Village → Lumbermill → Mine
- Переключить `_try_road_click` на модель «шаг по сегменту + выбор соседа
  у junction» ТОЛЬКО для этих рёбер.
- Проверить: герой едет, fog открывается, проезд Village/Lumbermill НЕ даёт
  `[LOCATION_ENTER]`, вход в Village только icon-click.
- Остальная карта пока на старом коде (или закрыта).

### Phase 3 — road encounters по offset
- Добавить `ENCOUNTERS[segment]` и триггер при пересечении offset на тестовом
  маршруте.
- Повесить 1–2 засады (напр. `Village-Lumbermill offset=320 bandit_ambush`)
  и проверить срабатывание + one_shot.

### Phase 4 — остальная карта
- Перевести оставшиеся рёбра (Dock, KnightRuins, MageTower, EarthMage,
  DarkCastle locked) на новую модель.
- Удалить мёртвый код из раздела 8.
- Обновить `ROADBOOK.*` под новую модель (отдельно, по разрешению).

---

## Резюме

Идея игры (идти по дороге + туман + засады) — правильная и соответствует жанру.
Проблема была не в идее, а в смешении дорожных узлов и локаций. Разделение
`junction ≠ location` + encounters по offset освобождает дорогу под главный
контент: засады, квесты, награды. Path2D, туман и offset-движение —
сохраняются и переиспользуются.
