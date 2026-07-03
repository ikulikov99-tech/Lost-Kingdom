# Lost Kingdom — Design Log

Журнал дизайн-решений: проблема → варианты → выбор → почему отвергли остальное.
Цель: чтобы Cowork и Code не передумывали с нуля. Новые записи добавлять сверху или в конец с датой.

---

## 1. Отказ от step-by-step movement

- **Старый вариант:** клик по дороге → шаги / угадывание направления.
- **Проблема:** tangent / dot / projection ломались на развилках (неоднозначное направление на кривых Path2D).
- **Решение:** V2 target-node navigation.
- **Принцип:** один клик = одно ребро между junctions (как Slay the Spire / Mario node-map).

## 2. Junction ≠ location

- **junction** = дорожная точка (узел графа дорог).
- **location** = событие / иконка / вход.
- **map-click** = движение / discover.
- **E** = explicit enter (вход в локацию — отдельное действие, не клик по карте).

## 3. Fog Direction Markers

- **Проблема:** следующий узел скрыт в тумане, по нему нельзя кликнуть.
- **Rejected:** nearest-adjacent / click direction guessing (tangent/dot/projection/«идти дальше»-меню).
- **Chosen:** кликабельный marker на краю тумана с явным `target_junction`.

## 4. MVP route

- Маршрут: **Castle → Village → Lumbermill → Mine**.
- Это **не вся игра**, а первый vertical slice.
- **Mine** = финал первого среза / вход глубже к тёмной части карты — **не** финал всей игры.

## 5. Combat not fixed yet

- Cowork предложил **bullet-heaven** как базовое направление.
- Пользователь предложил **Kingdom-like road defense** (защита героини на дороге, волны из тумана, временные баррикады/баллиста).
- **Финальное решение по `bandit_ambush` ещё не принято.**
- Нужно прогнать через `council-review` перед фиксацией формата.
