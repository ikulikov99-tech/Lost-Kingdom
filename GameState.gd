extends Node

## Герой по умолчанию для debug-запуска карты напрямую (минуя HeroSelect)
const DEBUG_DEFAULT_HERO := "female"

var selected_hero: String = "female"
var current_location: String = "Castle"
var unlocked_locations: Array[String] = ["Castle", "Village"]

func _ready() -> void:
	# Debug-флаг: работает ТОЛЬКО в дев-сборках (OS.is_debug_build()).
	# В экспортированном релизе путь всегда Splash -> HeroSelect -> Main.
	if OS.is_debug_build():
		call_deferred("_debug_quick_start")

func choose_hero(hero_id: String) -> void:
	selected_hero = hero_id
	current_location = "Castle"
	unlocked_locations = ["Castle", "Village"]

## Если Main.tscn запущен напрямую (F6 в редакторе / --scene из CLI),
## инициализируем состояние как после выбора героя по умолчанию.
## Обычный путь Splash -> HeroSelect не затрагивается: там current_scene = Splash.
func _debug_quick_start() -> void:
	var cs := get_tree().current_scene
	if cs != null and cs.scene_file_path == "res://Main.tscn":
		if selected_hero == "":
			selected_hero = DEBUG_DEFAULT_HERO
		choose_hero(selected_hero)
		print("[DEBUG] quick-start: Main.tscn запущен напрямую, герой: ", selected_hero)
