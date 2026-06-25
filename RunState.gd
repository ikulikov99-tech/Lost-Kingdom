extends Node

## RunState — состояние ОДНОГО забега (run), отдельно от persistent GameState.
## Autoload: переживает смену сцены, чтобы будущая encounter/бой-сцена могла
## вернуться на карту, не теряя прогресс забега.
##
## Phase 4A использует только: жизненный цикл run + дедуп road-encounter'ов
## (срабатывание один раз за забег). discovered/fog-reset за run — Phase 4B.
##
## ВАЖНО: формат боя НЕ зафиксирован. Road encounter сейчас — только stub/log.
## Позже bandit_ambush может стать отдельной маленькой сценой "road ambush
## defense" (враги из тумана, защита героини, монеты/осколки, временные
## баррикады/баллиста/катапульта, пережил волну → назад на карту) — ближе к
## Kingdom-like defense. Но это НЕ здесь и НЕ сейчас.

var active: bool = false
var run_id: int = 0
var fired_encounters: Dictionary = {}   # encounter_id -> true (дедуп за run)
var temp_rewards: Array = []            # ЗАГЛУШКА (Phase 4B+): лут текущего забега

# discovered/fog за текущий run — Phase 4B (миграция из Main.gd). Пока только задел.
# var run_discovered: Dictionary = {}

## Начать новый забег: сбросить run-состояние. Persistent (GameState) не трогаем.
func start_run() -> void:
	active = true
	run_id += 1
	fired_encounters.clear()
	temp_rewards.clear()
	print("[RUN] start run_id=%d" % run_id)

## Завершить забег (смерть/возврат). В Phase 4A не вызывается (нет Castle-экрана).
func end_run() -> void:
	active = false
	print("[RUN] end run_id=%d" % run_id)

func has_fired(encounter_id: String) -> bool:
	return fired_encounters.get(encounter_id, false)

func mark_fired(encounter_id: String) -> void:
	fired_encounters[encounter_id] = true
