extends GdUnitTestSuite

## Тест production-гейта титула: имя локации рисуется только для discovered.
## Инстанс создаётся БЕЗ add_child → _ready/_draw не запускаются, @onready (camera/
## hero/labels) не резолвятся; _should_draw_title читает только discovered, к нодам
## не обращается. gameplay не трогается.

const MainScript := preload("res://Main.gd")

func test_undiscovered_title_not_drawn() -> void:
	var main: Node = auto_free(MainScript.new())
	main.discovered = {"Castle": true}
	assert_bool(main._should_draw_title("Castle")).is_true()    # discovered → рисуется
	assert_bool(main._should_draw_title("Village")).is_false()  # undiscovered → НЕ рисуется
	assert_bool(main._should_draw_title("Mine")).is_false()     # вообще не в словаре → НЕ рисуется
