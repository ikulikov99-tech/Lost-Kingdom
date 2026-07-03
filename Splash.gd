extends Control

var stars: Array = []
const STAR_COUNT = 80

func _ready() -> void:
	_build_ui()
	_init_stars()

func _init_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in STAR_COUNT:
		stars.append({
			"x": rng.randf_range(0, 1280),
			"y": rng.randf_range(0, 720),
			"r": rng.randf_range(1.0, 2.5),
			"alpha": rng.randf_range(0.3, 1.0),
			"speed": rng.randf_range(0.3, 1.2),
			"t": rng.randf_range(0, TAU),
		})

func _process(delta: float) -> void:
	for s in stars:
		s["t"] += delta * s["speed"]
	queue_redraw()

func _draw() -> void:
	for s in stars:
		var a: float = float(s["alpha"]) * (0.5 + 0.5 * sin(float(s["t"])))
		var col := Color(0.78, 0.93, 0.72, a)
		draw_circle(Vector2(s["x"], s["y"]), s["r"], col)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.024, 0.059)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 12)
	add_child(center)

	var title := Label.new()
	title.text = "LOST KINGDOM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.29, 0.60, 0.88))
	center.add_child(title)

	var line := HSeparator.new()
	line.custom_minimum_size = Vector2(340, 1)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(line)

	var sub := Label.new()
	sub.text = "SHADOWS OF THE FORGOTTEN WORLD"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.23, 0.38, 0.53))
	center.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	center.add_child(spacer)

	var btn := Button.new()
	btn.text = "▶   НАЧАТЬ ИГРУ"
	btn.custom_minimum_size = Vector2(280, 52)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.50, 0.72, 0.91))
	btn.add_theme_color_override("font_hover_color", Color(0.82, 0.93, 1.0))
	center.add_child(btn)
	btn.pressed.connect(_on_start)

func _on_start() -> void:
	get_tree().change_scene_to_file("res://HeroSelect.tscn")
