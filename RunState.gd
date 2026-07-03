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

# ── Road encounter → бой → возврат на карту (bandit_ambush Step 1) ──
# Минимальный return-контекст: НЕ полноценная save-система. Autoload переживает
# смену сцены Main → Combat → Main, чтобы карта восстановилась без сброса прогресса.
var return_pending: bool = false         # есть незавершённый возврат на карту
var return_encounter: String = ""        # id сработавшего encounter
var return_segment: String = ""          # имя Path2D-сегмента
var return_ratio: float = 0.0            # доля пройденного пути [0..1]
var return_hero_pos: Vector2 = Vector2.ZERO
var return_current_location: String = ""
var return_current_junction: String = ""
var return_discovered: Dictionary = {}   # снимок discovered на момент засады

# Результат последнего боя (Step 1 — всегда win, заглушка) + placeholder-награда.
var last_combat_result: String = ""      # "win" / "loss" / ""
var last_combat_reward: String = ""      # человекочитаемо для [ROAD_ENCOUNTER_RESULT]
var gold: int = 0                        # placeholder-валюта забега

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

## Сохранить контекст возврата на карту ПЕРЕД уходом в боевую сцену. Карта (Main)
## восстановит себя из этих полей в _ready. fired_encounters НЕ трогаем → та же
## засада не повторится в этом забеге.
func begin_encounter(ctx: Dictionary) -> void:
	return_pending = true
	return_encounter = str(ctx.get("encounter", ""))
	return_segment = str(ctx.get("segment", ""))
	return_ratio = float(ctx.get("ratio", 0.0))
	return_hero_pos = ctx.get("hero_pos", Vector2.ZERO)
	return_current_location = str(ctx.get("location", ""))
	return_current_junction = str(ctx.get("junction", ""))
	return_discovered = ctx.get("discovered", {})
	print("[ROAD_ENCOUNTER_BEGIN] id=%s segment=%s ratio=%.2f" \
		% [return_encounter, return_segment, return_ratio])

## Зафиксировать победу + заглушку-награду (вызывает Combat перед возвратом).
func resolve_combat_win() -> void:
	last_combat_result = "win"
	gold += 10
	temp_rewards.append({"type": "gold", "amount": 10})
	last_combat_reward = "gold+10"
	print("[COMBAT] resolved result=win reward=%s gold=%d" % [last_combat_reward, gold])

## Очистить return-флаги после восстановления карты (encounter завершён).
func clear_return() -> void:
	return_pending = false
	return_encounter = ""
	return_segment = ""
	return_discovered = {}
