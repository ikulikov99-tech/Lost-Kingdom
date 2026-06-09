extends Control

var selected_hero := ""

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Фон
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.024, 0.059)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("separation", 0)
	add_child(center)

	# Заголовок LOST KINGDOM
	var title := Label.new()
	title.text = "LOST KINGDOM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.29, 0.60, 0.88))
	title.custom_minimum_size = Vector2(0, 100)
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	center.add_child(title)

	# Подзаголовок
	var sub := Label.new()
	sub.text = "Shadows of the Forgotten World"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.23, 0.38, 0.53))
	sub.custom_minimum_size = Vector2(0, 32)
	center.add_child(sub)

	# Линия
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 20)
	center.add_child(sep)

	# Надпись выбора
	var pick := Label.new()
	pick.text = "Выбери своего героя"
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick.add_theme_font_size_override("font_size", 13)
	pick.add_theme_color_override("font_color", Color(0.54, 0.69, 0.82))
	pick.custom_minimum_size = Vector2(0, 24)
	center.add_child(pick)

	var sub2 := Label.new()
	sub2.text = "Твой выбор определит судьбу королевства"
	sub2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub2.add_theme_font_size_override("font_size", 11)
	sub2.add_theme_color_override("font_color", Color(0.25, 0.40, 0.55))
	sub2.custom_minimum_size = Vector2(0, 32)
	center.add_child(sub2)

	# Карточки
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.custom_minimum_size = Vector2(0, 310)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(row)

	var spacer_l := Control.new()
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer_l)

	var card_f := _make_card("female",
		"res://characters/female_map/frame_1.png",
		"Аэри", "Страж  ·  Магия теней",
		"Последняя из клана.\nИщет брата в проклятом мире.")
	row.add_child(card_f)

	var card_m := _make_card("male",
		"res://characters/male_map/frame_1.png",
		"Арен", "Воин  ·  Тактик",
		"Бывший солдат.\nПопал в этот мир без предупреждения.")
	row.add_child(card_m)

	var spacer_r := Control.new()
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer_r)

	# Кнопка Начать
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.custom_minimum_size = Vector2(0, 70)
	btn_row.size_flags_vertical = Control.SIZE_SHRINK_END
	center.add_child(btn_row)

	var btn := Button.new()
	btn.name = "StartBtn"
	btn.text = "▶   Начать путешествие"
	btn.custom_minimum_size = Vector2(300, 50)
	btn.add_theme_font_size_override("font_size", 14)
	btn.disabled = true
	btn.pressed.connect(_on_start)
	btn_row.add_child(btn)

func _make_card(hero_id: String, img_path: String, name_text: String,
				class_text: String, desc_text: String) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(180, 300)
	card.name = "card_" + hero_id

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.059)
	style.border_color = Color(0.05, 0.094, 0.141)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var img := TextureRect.new()
	img.custom_minimum_size = Vector2(180, 200)
	img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex := load(img_path) as Texture2D
	if tex:
		img.texture = tex
	vbox.add_child(img)

	var lname := Label.new()
	lname.text = name_text
	lname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lname.add_theme_font_size_override("font_size", 15)
	lname.add_theme_color_override("font_color", Color(0.63, 0.78, 0.91))
	vbox.add_child(lname)

	var lclass := Label.new()
	lclass.text = class_text
	lclass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lclass.add_theme_font_size_override("font_size", 9)
	lclass.add_theme_color_override("font_color", Color(0.22, 0.40, 0.55))
	vbox.add_child(lclass)

	var ldesc := Label.new()
	ldesc.text = desc_text
	ldesc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ldesc.add_theme_font_size_override("font_size", 10)
	ldesc.add_theme_color_override("font_color", Color(0.27, 0.43, 0.55))
	ldesc.autowrap_mode = TextServer.AUTOWRAP_WORD_ARBITRARY
	ldesc.custom_minimum_size = Vector2(160, 0)
	ldesc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(ldesc)

	card.gui_input.connect(_on_card_click.bind(hero_id, card))
	return card

func _on_card_click(event: InputEvent, hero_id: String, card: Panel) -> void:
	if not (event is InputEventMouseButton and
			event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	selected_hero = hero_id
	# Сброс всех карточек
	for child in find_children("card_*", "Panel", false):
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.02, 0.035, 0.059)
		s.border_color = Color(0.05, 0.094, 0.141)
		s.set_border_width_all(2)
		s.set_corner_radius_all(10)
		child.add_theme_stylebox_override("panel", s)
	# Подсветить выбранную
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color(0.02, 0.04, 0.08)
	sel.border_color = Color(0.23, 0.50, 0.75)
	sel.set_border_width_all(2)
	sel.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", sel)
	# Активировать кнопку
	var btn := find_child("StartBtn", true, false) as Button
	if btn:
		btn.disabled = false

func _on_start() -> void:
	if selected_hero == "":
		return
	GameState.choose_hero(selected_hero)
	get_tree().change_scene_to_file("res://Main.tscn")
