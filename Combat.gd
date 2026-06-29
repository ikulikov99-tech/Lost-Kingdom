extends Control

## bandit_ambush Step 1 — ПЛЕЙСХОЛДЕР боевой сцены. Реального боя НЕТ: показываем
## баннер «Засада разбойников», через короткий таймер — «Победа», по кнопке/клавише
## «Продолжить» фиксируем win + заглушку-награду в RunState и возвращаемся на карту.
## Враги / HP / атаки / поражение / баланс — НЕ здесь (Step 2/3). Цель Step 1 —
## проверить стык карта → бой → возврат, не сам бой.

const WIN_DELAY := 1.5            # сек до автопоказа «Победа» (авто-резолв в win)
const RETURN_SCENE := "res://Main.tscn"

var _title: Label
var _hint: Label
var _continue: Button
var _won := false
var _returning := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.05, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	_title = Label.new()
	_title.text = "Засада разбойников"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 42)
	box.add_child(_title)

	_hint = Label.new()
	_hint.text = "Разбойники выходят из тумана…"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 20)
	box.add_child(_hint)

	_continue = Button.new()
	_continue.text = "Продолжить"
	_continue.visible = false
	_continue.pressed.connect(_return_to_map)
	box.add_child(_continue)

	print("[COMBAT] enter scene encounter=%s" % RunState.return_encounter)
	get_tree().create_timer(WIN_DELAY).timeout.connect(_show_victory)

## Авто-победа по таймеру (Step 1 — бой всегда выигран).
func _show_victory() -> void:
	if _won:
		return
	_won = true
	RunState.resolve_combat_win()
	_title.text = "Победа!"
	_hint.text = "Путь свободен. Награда: %s (заглушка). Нажми «Продолжить»." \
		% RunState.last_combat_reward
	_continue.visible = true
	_continue.grab_focus()

## После победы продолжить можно и кликом/Enter/Space (на случай потери фокуса кнопки).
func _unhandled_input(event: InputEvent) -> void:
	if not _won:
		return
	if event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed):
		_return_to_map()

func _return_to_map() -> void:
	if _returning:
		return
	_returning = true
	print("[COMBAT] return to map result=win")
	get_tree().change_scene_to_file(RETURN_SCENE)
