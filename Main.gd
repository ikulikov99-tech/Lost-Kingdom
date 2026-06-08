extends Node2D

const CLICK_RADIUS := 32.0
const LABEL_FONT_SIZE := 14

var waypoints := {
	"Castle": {
		"pos": Vector2(390, 165),
		"unlocked": true,
		"adjacent": ["Village", "Mine"]
	},
	"Village": {
		"pos": Vector2(640, 390),
		"unlocked": true,
		"adjacent": ["Castle", "Ruins", "MageTower"]
	},
	"Mine": {
		"pos": Vector2(310, 500),
		"unlocked": true,
		"adjacent": ["Castle"]
	},
	"Ruins": {
		"pos": Vector2(800, 345),
		"unlocked": false,
		"adjacent": ["Village", "MageTower"]
	},
	"MageTower": {
		"pos": Vector2(975, 490),
		"unlocked": false,
		"adjacent": ["Village", "Ruins"]
	},
}

@onready var hero: Node2D = $Hero

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Draw roads between adjacent waypoints
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

	# Draw waypoint circles + labels
	for name in waypoints:
		var wp = waypoints[name]
		var is_open: bool = wp["unlocked"]

		# Circle fill
		var fill := Color(0.18, 0.75, 0.28) if is_open else Color(0.30, 0.30, 0.30, 0.85)
		draw_circle(wp["pos"], 16.0, fill)

		# Circle border
		var border := Color(1.0, 0.95, 0.6, 1.0) if is_open else Color(0.55, 0.55, 0.55, 0.8)
		draw_arc(wp["pos"], 16.0, 0.0, TAU, 48, border, 2.5)

		# Label background + text
		var label_size := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
		var label_pos := wp["pos"] + Vector2(-label_size.x * 0.5, -26.0)
		draw_rect(
			Rect2(label_pos + Vector2(-4, -label_size.y - 2), label_size + Vector2(8, 6)),
			Color(0.0, 0.0, 0.0, 0.72)
		)
		var text_color := Color(1.0, 1.0, 0.85) if is_open else Color(0.6, 0.6, 0.6)
		draw_string(font, label_pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, text_color)

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
