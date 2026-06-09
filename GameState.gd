extends Node

var selected_hero: String = "female"
var current_location: String = "Castle"
var unlocked_locations: Array[String] = ["Castle", "Village"]

func choose_hero(hero_id: String) -> void:
	selected_hero = hero_id
	current_location = "Castle"
	unlocked_locations = ["Castle", "Village"]
