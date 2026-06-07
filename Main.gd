extends Node2D

const CLICK_RADIUS := 30.0

var waypoints := {
	"Castle": {
		"pos": Vector2(220, 490),
		"unlocked": true,
		"adjacent": ["Village", "Mine"]
	},
	"Village": {
		"pos": Vector2(430, 400),
		"unlocked": true,
		"adjacent": ["Castle", "Ruins", "MageTower"]
	},
	"Mine": {
		"pos": Vector2(170, 600),
		"unlocked": true,
		"adjacent": ["Castle"]
	},
	"Ruins": {
		"pos": Vector2(650, 270),
		"unlocked": false,
		"adjacent": ["Village", "MageTower"]
	},
	"MageTower": {
		"pos": Vector2(880, 430),
		"unlocked": false,
		"adjacent": ["Village", "Ruins"]
	},
}

@onready var hero: Node2D = $Hero

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var drawn: Array = []
	for name in waypoints:
		var wp = waypoints[name]
		for neighbor in wp["adjacent"]:
			var pair := [name, neighbor]
			pair.sort()
			if pair in drawn:
				continue
			drawn.append(pair)
			var color := Color(0.55, 0.35, 0.15, 0.85) if waypoints[neighbor]["unlocked"] and wp["unlocked"] else Color(0.3, 0.3, 0.3, 0.5)
			draw_line(wp["pos"], waypoints[neighbor]["pos"], color, 4.0)

	for name in waypoints:
		var wp = waypoints[name]
		var fill := Color(0.2, 0.8, 0.3) if wp["unlocked"] else Color(0.35, 0.35, 0.35, 0.9)
		var border := Color(1, 1, 1, 0.9) if wp["unlocked"] else Color(0.5, 0.5, 0.5, 0.7)
		draw_circle(wp["pos"], 16.0, fill)
		draw_arc(wp["pos"], 16.0, 0.0, TAU, 48, border, 2.5)
		var font := ThemeDB.fallback_font
		draw_string(font, wp["pos"] + Vector2(-24, -22), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.95))

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
