extends GdUnitTestSuite

## Data-тесты V2-графа. Читают ТОЛЬКО консты Main.gd через загруженный скрипт —
## Main НЕ инстанцируется, _ready не вызывается, gameplay не трогается.
## Цели 1–3 из задачи на первые GdUnit4-тесты (цель 4 — рендер undiscovered title —
## требует инстанса сцены/выноса функции, вынесена в отдельный план, тут не тестируется).

const MainScript := preload("res://Main.gd")

## Соседи junction по сегментам V2 (зеркалит data-логику _v2_adjacent_junctions,
## но без инстанса Main — читаем только ROAD_SEGMENTS_V2).
func _v2_neighbors(junction_id: String) -> Array:
	var out: Array = []
	for seg in MainScript.ROAD_SEGMENTS_V2:
		if str(seg[0]) == junction_id:
			out.append(str(seg[1]))
		elif str(seg[1]) == junction_id:
			out.append(str(seg[0]))
	return out

# 1. MVP route Castle → Village → Lumbermill → Mine связен в V2-графе.
func test_mvp_route_connected_in_v2() -> void:
	assert_array(_v2_neighbors("CastleJunction")).contains(["VillageJunction"])
	assert_array(_v2_neighbors("VillageJunction")).contains(["LumbermillJunction"])
	assert_array(_v2_neighbors("LumbermillJunction")).contains(["MineJunction"])

# 2. ROAD_SEGMENTS_V2 содержит РОВНО текущие 3 active-ребра (по имени Path2D).
func test_v2_segments_are_exactly_current_active() -> void:
	var paths: Array = []
	for seg in MainScript.ROAD_SEGMENTS_V2:
		paths.append(str(seg[2]))
	assert_array(paths).contains_exactly_in_any_order([
		"CastleVillagePath", "VillageLumbermillPath", "LumbermillMinePath",
	])

# 3. Неактивные ветки (Village→Dock / Village→KnightRuins / Mine→EarthMage)
#    не являются обычными active V2-сегментами.
func test_inactive_branches_not_in_v2() -> void:
	assert_array(_v2_neighbors("VillageJunction")).not_contains(["DockJunction"])
	assert_array(_v2_neighbors("VillageJunction")).not_contains(["KnightRuinsJunction"])
	assert_array(_v2_neighbors("MineJunction")).not_contains(["EarthMageJunction"])
