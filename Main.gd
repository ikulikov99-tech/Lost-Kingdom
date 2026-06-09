extends Node2D

@onready var hero: CharacterBody2D = $Hero
@onready var current_label: Label = $UI/StatusPanel/CurrentLabel
@onready var unlocked_label: Label = $UI/StatusPanel/UnlockedLabel

const WAYPOINTS := {
	"Castle":    Vector2(-590, -240),
	"Village":   Vector2(-435, -20),
	"Mine":      Vector2(-35, -315),
	"Ruins":     Vector2(-330, 125),
	"MageTower": Vector2(0, 285),
}

const ROUTES := {
	"Castle": ["Village"],
	"Village": ["Castle", "Mine", "Ruins"],
	"Mine": ["Village"],
	"Ruins": ["Village", "MageTower"],
	"MageTower": ["Ruins"],
}

var current_location := "Castle"
var unlocked := {
	"Castle": true,
	"Village": true,
	"Mine": false,
	"Ruins": false,
	"MageTower": false,
}

func _ready() -> void:
	current_location = GameState.current_location
	hero.global_position = WAYPOINTS[current_location]
	hero.arrived.connect(_on_hero_arrived)
	_update_ui()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked := _find_clicked_waypoint(get_global_mouse_position())
		if clicked != "":
			_try_move_to(clicked)

func _find_clicked_waypoint(mouse_pos: Vector2) -> String:
	for name in WAYPOINTS.keys():
		if mouse_pos.distance_to(WAYPOINTS[name]) < 45.0:
			return name
	return ""

func _try_move_to(location_name: String) -> void:
	if not unlocked.get(location_name, false):
		return
	if location_name == current_location:
		return
	if not ROUTES[current_location].has(location_name):
		return
	hero.move_to(location_name, WAYPOINTS[location_name])

func _on_hero_arrived(location_name: String) -> void:
	current_location = location_name
	GameState.current_location = location_name
	for neighbor in ROUTES[location_name]:
		unlocked[neighbor] = true
	GameState.unlocked_locations = _get_unlocked_list()
	_update_ui()
	queue_redraw()

func _get_unlocked_list() -> Array[String]:
	var result: Array[String] = []
	for name in unlocked.keys():
		if unlocked[name]:
			result.append(name)
	return result

func _update_ui() -> void:
	current_label.text = "Current: " + current_location
	unlocked_label.text = "Unlocked: " + ", ".join(_get_unlocked_list())

func _draw() -> void:
	# Draw roads above the map.
	var drawn := {}
	for a in ROUTES.keys():
		for b in ROUTES[a]:
			var key := [a, b]
			key.sort()
			var route_key := str(key[0]) + "-" + str(key[1])
			if drawn.has(route_key):
				continue
			drawn[route_key] = true
			draw_line(WAYPOINTS[a], WAYPOINTS[b], Color(1.0, 0.85, 0.35, 0.75), 4.0)

	for name in WAYPOINTS.keys():
		var color := Color(0.2, 0.9, 0.25, 1.0) if unlocked.get(name, false) else Color(0.35, 0.35, 0.35, 0.85)
		if name == current_location:
			color = Color(0.2, 0.55, 1.0, 1.0)
		draw_circle(WAYPOINTS[name], 18.0, color)
		draw_arc(WAYPOINTS[name], 22.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 3.0)
