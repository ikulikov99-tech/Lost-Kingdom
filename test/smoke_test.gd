extends GdUnitTestSuite

## Smoke-тест: проверяет, что сам GdUnit4 runner работает в этом проекте.
## Никакого gameplay/Main.gd — только тривиальные ассерты.

func test_runner_smoke() -> void:
	assert_bool(true).is_true()
	assert_int(1 + 1).is_equal(2)
