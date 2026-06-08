extends Node2D

const CLICK_RADIUS := 35.0
const LABEL_FONT_SIZE := 14

# Координаты в системе старой сцены (WorldMap center = (12, -53), scale = 1)
var waypoints := {
	"Castle": {
		"pos": Vector2(-300, -200),
		"unlocked": true,
		"adjacent": ["Village", "Mine"]
	},
	"Village": {
		"pos": Vector2(100, 20),
		"unlocked": true,
		"adjacent": ["Castle", "Ruins", "MageTower"]
	},
	"Mine": {
		"pos": Vector2(-400, 180),
		"unlocked": true,
		"adjacent": ["Castle"]
	},
	"Ruins": {
		"pos": Vector2(260, -100),
		"unlocked": false,
		"adjacent": ["Village", "MageTower"]
	},
	"MageTower": {
		"pos": Vector2(560, 170),
		"unlocked": false,
		"adjacent": ["Village", "Ruins"]
	},
}

@onready var hero: Node2D = $Hero

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Дороги между соседними точками
	var drawn: Array = []
	for name in waypoints:
		var wp = waypoints[name]
		for neighbor in wp["adjacent"]:
			var pair := [name, neighbor]
			pair.sort()
			if pair in drawn:
				continue
			drawn.append(pair)
			var both_open := waypoints[neighbor]["unlocked"] and wp["unlocked"]
			var road_color := Color(0.65, 0.42, 0.15, 0.9) if both_open else Color(0.35, 0.35, 0.35, 0.5)
			draw_line(wp["pos"], waypoints[neighbor]["pos"], road_color, 4.0)

	# Маркеры точек (флажок-булавка)
	for name in waypoints:
		var wp = waypoints[name]
		var is_open: bool = wp["unlocked"]
		var p := wp["pos"]

		# Цвета: открытая = золотая, закрытая = тёмная
		var pin_color := Color(0.95, 0.75, 0.1) if is_open else Color(0.25, 0.25, 0.25, 0.9)
		var border_color := Color(1.0, 1.0, 1.0, 0.95) if is_open else Color(0.5, 0.5, 0.5, 0.8)

		# Тело пина: круг
		draw_circle(p, 14.0, pin_color)
		draw_arc(p, 14.0, 0.0, TAU, 32, border_color, 2.0)

		# Хвостик вниз
		draw_line(p, p + Vector2(0, 20), border_color, 2.5)
		draw_circle(p + Vector2(0, 22), 3.5, border_color)

		# Подпись НАД маркером
		var pad := 5
		var fs := LABEL_FONT_SIZE
		var label_w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var label_h := fs + 4
		var lx := p.x - label_w * 0.5 - pad
		var ly := p.y - 14 - label_h - 8

		# Фон подписи
		draw_rect(Rect2(lx, ly, label_w + pad * 2, label_h + 4),
			Color(0.0, 0.0, 0.0, 0.78), true)
		draw_rect(Rect2(lx, ly, label_w + pad * 2, label_h + 4),
			border_color, false, 1.5)

		# Текст
		var text_col := Color(1.0, 1.0, 0.8) if is_open else Color(0.65, 0.65, 0.65)
		draw_string(font, Vector2(lx + pad, ly + fs + 1),
			name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_col)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if hero.is_moving:
		return
	var click_pos := get_global_mouse_position()
	for name in waypoints:
		var wp = waypoints[name]
		if click_pos.distance_to(wp["pos"]) > CLICK_RADIUS:
			continue
		if not wp["unlocked"]:
			return
		if name == hero.current_waypoint:
			return
		if name not in waypoints[hero.current_waypoint]["adjacent"]:
			return
		hero.move_to(name, wp["pos"])
		return

func on_hero_arrived(waypoint_name: String) -> void:
	for neighbor in waypoints[waypoint_name]["adjacent"]:
		waypoints[neighbor]["unlocked"] = true
	queue_redraw()
