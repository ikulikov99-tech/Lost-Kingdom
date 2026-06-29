extends Control

## bandit_ambush Step 2A — боевая сцена с проверяемым ГЛАЗАМИ плейсхолдером.
## Реального боя НЕТ (врагов/атаки/HP/урона/поражения — это Step 2B+/Step 3).
## Здесь: героиня-примитив со свободным 8-directional движением (WASD/стрелки) внутри
## процедурной арены (ColorRect/Panel, без картинок), читаемый UI и РУЧНОЕ завершение
## боя (кнопка «Завершить бой (тест)» или Enter) — БЕЗ мгновенного авто-win по таймеру.
## Контракт со Step 1 не тронут: победа = RunState.resolve_combat_win() + возврат на
## res://Main.tscn. Hero.gd НЕ переиспользуется (он привязан к дороге).

const RETURN_SCENE := "res://Main.tscn"

# ── движение героини ──
const HERO_SPEED := 320.0          # px/сек
const HERO_RADIUS := 23.0          # радиус тела примитива
const HERO_CLAMP_R := 30.0         # отступ центра от границы арены (тело + ореол)
const ARENA_MARGIN := 40.0         # отступ арены от краёв экрана (= граница движения)

# ── бандиты (Step 2B: ТОЛЬКО спавн + преследование по прямой; без атаки/HP/смерти) ──
const BANDIT_SPEED := 150.0        # px/сек, медленнее героини → её можно увести
const BANDIT_RADIUS := 18.0
const BANDIT_CLAMP_R := 24.0       # отступ центра бандита от границы арены

var _title: Label
var _hint: Label
var _action_btn: Button
var _won := false
var _returning := false

var _hero: Node2D
var _hero_pos: Vector2 = Vector2.ZERO   # центр героини в координатах сцены

var _bandits: Array[Node2D] = []        # узлы-бандиты; позиция = .position
var _count_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Фон — тёмный, но не «чёрная пустота».
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.09, 0.08, 0.12, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_arena()
	_spawn_bandits()   # до героини и UI: z-порядок арена < бандиты < героиня < UI
	_build_hero()
	_build_ui()

	_hero_pos = get_viewport_rect().size * 0.5
	_clamp_hero()
	_hero.position = _hero_pos

	print("[COMBAT] enter scene encounter=%s" % RunState.return_encounter)
	print("[COMBAT_STEP2A] hero movement ready")

## Процедурная арена с видимой рамкой (Panel + StyleBoxFlat, без картинки).
func _build_arena() -> void:
	var arena := Panel.new()
	arena.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena.offset_left = ARENA_MARGIN
	arena.offset_top = ARENA_MARGIN
	arena.offset_right = -ARENA_MARGIN
	arena.offset_bottom = -ARENA_MARGIN
	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.13, 0.18, 1.0)
	sb.border_color = Color(0.52, 0.48, 0.64, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	arena.add_theme_stylebox_override("panel", sb)
	add_child(arena)

## Героиня — заметный примитив: круг 46px + ореол + контур + подпись «Hero».
func _build_hero() -> void:
	_hero = Node2D.new()
	add_child(_hero)

	var body_pts := _circle_points(HERO_RADIUS, 28)

	var halo := Polygon2D.new()
	halo.polygon = _circle_points(HERO_RADIUS + 9.0, 28)
	halo.color = Color(0.98, 0.85, 0.35, 0.20)
	_hero.add_child(halo)

	var body := Polygon2D.new()
	body.polygon = body_pts
	body.color = Color(0.97, 0.84, 0.33, 1.0)
	_hero.add_child(body)

	var outline := Line2D.new()
	var loop := body_pts.duplicate()
	loop.append(body_pts[0])
	outline.points = loop
	outline.width = 2.5
	outline.default_color = Color(0.16, 0.12, 0.04, 1.0)
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	_hero.add_child(outline)

	var tag := Label.new()
	tag.text = "Hero"
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", Color(0.97, 0.92, 0.75, 1.0))
	tag.position = Vector2(-18.0, HERO_RADIUS + 4.0)
	_hero.add_child(tag)

## UI: заголовок/подсказка сверху (по центру, не обрезается), кнопка снизу по центру.
func _build_ui() -> void:
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = ARENA_MARGIN + 16.0
	top.offset_right = -(ARENA_MARGIN + 16.0)
	top.offset_top = ARENA_MARGIN + 24.0
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	_title = Label.new()
	_title.text = "Засада разбойников"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	top.add_child(_title)

	_hint = Label.new()
	_hint.text = "WASD / стрелки — движение\nEnter / кнопка — завершить тест боя"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 20)
	top.add_child(_hint)

	_count_label = Label.new()
	_count_label.text = "Бандитов: %d" % _bandits.size()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 22)
	_count_label.add_theme_color_override("font_color", Color(0.95, 0.6, 0.55, 1.0))
	top.add_child(_count_label)

	var bottom := CenterContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -(ARENA_MARGIN + 78.0)
	bottom.offset_bottom = -(ARENA_MARGIN + 18.0)
	add_child(bottom)

	_action_btn = Button.new()
	_action_btn.text = "Завершить бой (тест)"
	_action_btn.custom_minimum_size = Vector2(280.0, 46.0)
	_action_btn.pressed.connect(_on_action)
	bottom.add_child(_action_btn)

## Точки окружности вокруг (0,0) для Polygon2D/Line2D.
func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

## Свободное 8-directional движение героини + удержание в границах арены.
func _process(delta: float) -> void:
	var dir := _read_move_input()
	if dir != Vector2.ZERO:
		_hero_pos += dir.normalized() * HERO_SPEED * delta
		_clamp_hero()
		_hero.position = _hero_pos
	if not _won:
		_move_bandits(delta)

## Сумма WASD + стрелок (физические клавиши — не зависят от раскладки). Диагональ
## нормализуется в _process, поэтому все 8 направлений равны по скорости.
func _read_move_input() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	return dir

## Держать центр героини внутри арены (с учётом тела/ореола).
func _clamp_hero() -> void:
	_hero_pos = _clamp_to_arena(_hero_pos, HERO_CLAMP_R)

## Зажать точку внутри арены с отступом r (общий хелпер для героини и бандитов).
func _clamp_to_arena(p: Vector2, r: float) -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(
		clampf(p.x, ARENA_MARGIN + r, vp.x - ARENA_MARGIN - r),
		clampf(p.y, ARENA_MARGIN + r, vp.y - ARENA_MARGIN - r))

## Спавн 3 бандитов в фиксированных точках у КРАЁВ арены (визуально «из края/тумана»,
## без нового арта). Только появление — атаки/HP/смерти нет (Step 2B).
func _spawn_bandits() -> void:
	var vp := get_viewport_rect().size
	var edge := ARENA_MARGIN + BANDIT_CLAMP_R
	var points: Array[Vector2] = [
		Vector2(edge, vp.y * 0.30),            # левый край
		Vector2(vp.x - edge, vp.y * 0.42),     # правый край
		Vector2(vp.x * 0.5, edge),             # верхний край
	]
	for p: Vector2 in points:
		var b := _make_bandit()
		b.position = p
		add_child(b)
		_bandits.append(b)
	print("[COMBAT_STEP2B] spawned bandits=%d" % _bandits.size())

## Бандит — примитив, читаемо отличается от героини (тёмно-красный, меньше круг) +
## мягкая «дымка» по краю вместо нового арта (намёк на выход из тумана).
func _make_bandit() -> Node2D:
	var n := Node2D.new()

	var fog := Polygon2D.new()
	fog.polygon = _circle_points(BANDIT_RADIUS + 12.0, 24)
	fog.color = Color(0.20, 0.18, 0.26, 0.35)
	n.add_child(fog)

	var body := Polygon2D.new()
	body.polygon = _circle_points(BANDIT_RADIUS, 24)
	body.color = Color(0.74, 0.22, 0.20, 1.0)
	n.add_child(body)

	var loop := _circle_points(BANDIT_RADIUS, 24)
	loop.append(loop[0])
	var outline := Line2D.new()
	outline.points = loop
	outline.width = 2.0
	outline.default_color = Color(0.10, 0.04, 0.04, 1.0)
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	n.add_child(outline)

	return n

## Бандиты идут по ПРЯМОЙ к героине (без pathfinding). Преследуют, пока она движется.
## Урона/смерти/коллизий нет — только движение (Step 2B).
func _move_bandits(delta: float) -> void:
	for b: Node2D in _bandits:
		var to_hero := _hero_pos - b.position
		if to_hero.length() > 1.0:
			b.position += to_hero.normalized() * BANDIT_SPEED * delta
		b.position = _clamp_to_arena(b.position, BANDIT_CLAMP_R)

## Кнопка/Enter: в бою — завершить тест-бой (win); после победы — вернуться на карту.
func _on_action() -> void:
	if _won:
		_return_to_map()
	else:
		_win()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_action()
		return
	if _won and event is InputEventMouseButton and event.pressed:
		_return_to_map()

## Ручная победа (Step 2A — бой всегда выигран). Step 1 контракт без изменений.
func _win() -> void:
	if _won:
		return
	_won = true
	RunState.resolve_combat_win()
	_title.text = "Победа!"
	_hint.text = "Путь свободен. Награда: %s (заглушка). Нажми «Продолжить»." \
		% RunState.last_combat_reward
	_action_btn.text = "Продолжить"
	_action_btn.grab_focus()

func _return_to_map() -> void:
	if _returning:
		return
	_returning = true
	print("[COMBAT] return to map result=win")
	get_tree().change_scene_to_file(RETURN_SCENE)
