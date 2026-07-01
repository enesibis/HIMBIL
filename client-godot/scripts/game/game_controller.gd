class_name GameController
extends Node

## Ağsız oyun döngüsü: deste, takas tick'i, slam penceresi, puanlama.
## Aşama 3'te bu sınıfın state'i Colyseus odasına taşınacak; şu an tamamen
## client-local çalışıyor (Aşama 2: tek kişilik + bot).

signal phase_changed(phase: String)
signal hands_updated(hands: Array, changed_slot: int)
signal swap_resolved(passed_cards: Array, direction: int)
signal countdown_tick(seconds_left: float)
signal slam_window_opened(eligible: Array)
signal slam_attempt_recorded(player_id: String)
signal false_slam_penalty(player_id: String, new_score: int)
signal round_scored(results: Array, scores: Dictionary)
signal game_over(winner_id: String, scores: Dictionary)

const NUM_PLAYERS := 4
const SWAP_TICK_DURATION := 5.0
const SLAM_WINDOW_DURATION := 4.0
const TARGET_SCORE := 300
const HUMAN_ID := "human"

var player_ids: Array = [HUMAN_ID, "bot_east", "bot_north", "bot_west"]
var hands: Array = []
var scores: Dictionary = {}
var phase: String = "waiting"
var direction: int = 1

var _pending_choice: Dictionary = {}
var _swap_timer: float = 0.0
var _slam_timer: float = 0.0
var _slam_attempts: Array = []
var _recorded_players: Array = []
var _slam_candidates: Array = []


func _ready() -> void:
	randomize()
	for pid in player_ids:
		scores[pid] = 0
	start_new_round()


func start_new_round() -> void:
	var object_types := Rules.pick_object_types(NUM_PLAYERS)
	var deck := Rules.create_deck(NUM_PLAYERS, object_types)
	deck.shuffle()
	var dealt := Rules.deal_hands(deck, NUM_PLAYERS)
	hands = dealt["hands"]
	_pending_choice.clear()
	_slam_attempts.clear()
	hands_updated.emit(hands, -1)
	_check_quartets_or_start_swapping()


func submit_human_choice(card_id: int) -> void:
	if phase != "swapping":
		return
	_pending_choice[0] = card_id


## The HIMBIL button is always pressable. Returns what happened:
## "recorded" - counted toward this window's arrival-order scoring
## "already" - you'd already pressed this window
## "false_start" - no quartet exists anywhere right now; penalized
func submit_human_slam() -> String:
	if phase == "slamWindow":
		if _recorded_players.has(0):
			return "already"
		_record_slam_attempt(0)
		return "recorded"

	scores[HUMAN_ID] += Rules.FALSE_SLAM_PENALTY
	false_slam_penalty.emit(HUMAN_ID, scores[HUMAN_ID])
	return "false_start"


func _process(delta: float) -> void:
	if phase == "swapping":
		_swap_timer -= delta
		countdown_tick.emit(max(_swap_timer, 0.0))
		if _swap_timer <= 0.0:
			_resolve_swap()
	elif phase == "slamWindow":
		_slam_timer -= delta
		countdown_tick.emit(max(_slam_timer, 0.0))
		_process_bot_slams(delta)
		if _slam_timer <= 0.0:
			_finish_slam_window()


func _resolve_swap() -> void:
	var choices: Array = []
	for i in range(NUM_PLAYERS):
		if i == 0:
			choices.append({"card_id": _pending_choice.get(0, null)})
		else:
			choices.append({"card_id": BotAI.decide_card_to_pass(hands[i])})

	var result := Rules.resolve_swap_tick(hands, choices, direction)
	hands = result["hands"]
	_pending_choice.clear()
	swap_resolved.emit(result["passed_cards"], direction)
	hands_updated.emit(hands, result["changed_index"][0])
	_check_quartets_or_start_swapping()


## Checks all hands for a completed quartet (used right after dealing and
## after every swap tick, since a quartet can already exist before anyone
## has passed a single card). Opens the slam window if one exists,
## otherwise starts/continues the swapping countdown.
func _check_quartets_or_start_swapping() -> void:
	var any_quartet := false
	for h in hands:
		if Rules.detect_quartet(h) != "":
			any_quartet = true
			break

	if any_quartet:
		_open_slam_window()
	else:
		_swap_timer = SWAP_TICK_DURATION
		_set_phase("swapping")


func _open_slam_window() -> void:
	_set_phase("slamWindow")
	_slam_timer = SLAM_WINDOW_DURATION
	_slam_attempts.clear()
	_recorded_players.clear()
	_slam_candidates.clear()
	for i in range(NUM_PLAYERS):
		if i != 0 and Rules.detect_quartet(hands[i]) != "":
			_slam_candidates.append({"index": i, "delay": BotAI.decide_slam_delay(), "elapsed": 0.0, "done": false})
	slam_window_opened.emit(_slam_candidates)


func _process_bot_slams(delta: float) -> void:
	for entry in _slam_candidates:
		if entry["done"]:
			continue
		entry["elapsed"] += delta
		if entry["elapsed"] >= entry["delay"]:
			entry["done"] = true
			_record_slam_attempt(entry["index"])


func _record_slam_attempt(player_index: int) -> void:
	if _recorded_players.has(player_index):
		return
	_recorded_players.append(player_index)
	_slam_attempts.append(player_ids[player_index])
	slam_attempt_recorded.emit(player_ids[player_index])


func _finish_slam_window() -> void:
	var results := Rules.score_slam_order(_slam_attempts)
	for r in results:
		scores[r["player_id"]] += r["score"]
	_set_phase("scoring")
	round_scored.emit(results, scores)

	var winner := _find_winner()
	await get_tree().create_timer(2.5).timeout
	if winner != "":
		_set_phase("finished")
		game_over.emit(winner, scores)
	else:
		start_new_round()


func _find_winner() -> String:
	for pid in player_ids:
		if scores[pid] >= TARGET_SCORE:
			return pid
	return ""


func _set_phase(new_phase: String) -> void:
	phase = new_phase
	phase_changed.emit(new_phase)
