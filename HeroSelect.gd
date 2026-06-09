extends Control

func _ready() -> void:
	$Panel/MaleButton.pressed.connect(_choose_male)
	$Panel/FemaleButton.pressed.connect(_choose_female)

func _choose_male() -> void:
	GameState.choose_hero("male")
	get_tree().change_scene_to_file("res://Main.tscn")

func _choose_female() -> void:
	GameState.choose_hero("female")
	get_tree().change_scene_to_file("res://Main.tscn")
