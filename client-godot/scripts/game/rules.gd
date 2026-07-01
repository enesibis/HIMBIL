class_name Rules
extends RefCounted

## Ağdan bağımsız kural motoru (server/game/ TypeScript sürümünün GDScript
## karşılığı). Tek kişilik + bot modu bu motoru ağ olmadan doğrudan kullanır.

const OBJECT_POOL := ["elma", "armut", "muz", "cilek"]
const HAND_SIZE := 4

const SLAM_SCORE_START := 100
const SLAM_SCORE_STEP := 25
const FALSE_SLAM_PENALTY := -25


static func pick_object_types(num_players: int, pool: Array = OBJECT_POOL) -> Array:
	assert(num_players >= 2, "numPlayers must be at least 2")
	assert(num_players <= pool.size(), "object pool too small")
	return pool.slice(0, num_players)


static func create_deck(num_players: int, object_types: Array = []) -> Array:
	if object_types.is_empty():
		object_types = pick_object_types(num_players)
	var deck: Array = []
	var id := 0
	for object_type in object_types:
		for _copy in range(num_players):
			deck.append({"id": id, "object_type": object_type})
			id += 1
	return deck


static func deal_hands(deck: Array, num_players: int) -> Dictionary:
	var needed := num_players * HAND_SIZE
	assert(deck.size() >= needed, "deck too small")
	var hands: Array = []
	for _p in range(num_players):
		hands.append([])
	var cursor := 0
	for _round_i in range(HAND_SIZE):
		for p in range(num_players):
			hands[p].append(deck[cursor])
			cursor += 1
	return {"hands": hands, "stock": deck.slice(cursor)}


static func detect_quartet(hand: Array) -> String:
	if hand.is_empty():
		return ""
	var first: String = hand[0]["object_type"]
	for card in hand:
		if card["object_type"] != first:
			return ""
	return first


## choices[i] = { "card_id": int or null }. null triggers a random pick
## (matches the server doc's timeout rule).
##
## Cards are replaced in place: the slot a player gave away is the same
## slot the incoming card lands in, so the other 3 cards never shift
## position. `changed_index[i]` tells the UI which slot to animate.
static func resolve_swap_tick(hands: Array, choices: Array, direction: int) -> Dictionary:
	var num_players := hands.size()
	assert(choices.size() == num_players, "choices length must match number of players")

	var outgoing: Array = []
	var outgoing_index: Array = []

	for i in range(num_players):
		var hand: Array = hands[i]
		var card_id = choices[i].get("card_id", null)
		if card_id == null:
			card_id = hand[randi() % hand.size()]["id"]

		var card_index := -1
		for j in range(hand.size()):
			if hand[j]["id"] == card_id:
				card_index = j
				break
		assert(card_index != -1, "player %d chose a card not in their hand" % i)

		outgoing.append(hand[card_index])
		outgoing_index.append(card_index)

	var new_hands: Array = []
	for i in range(num_players):
		var sender_index := ((i - direction) % num_players + num_players) % num_players
		var new_hand: Array = hands[i].duplicate()
		new_hand[outgoing_index[i]] = outgoing[sender_index]
		new_hands.append(new_hand)

	return {"hands": new_hands, "passed_cards": outgoing, "changed_index": outgoing_index}


## Scores an already-open slam window's presses in arrival order (100, 75,
## 50, 25, ... floored at 0). The window only exists because a real quartet
## triggered it, so every press inside it is a legitimate reaction —
## there is no per-player quartet check here. False slams (pressing when
## no quartet exists anywhere, i.e. no window is open) are penalized
## separately at press time, not scored here.
static func score_slam_order(player_ids_in_order: Array) -> Array:
	var results: Array = []
	for i in range(player_ids_in_order.size()):
		var score = max(0, SLAM_SCORE_START - SLAM_SCORE_STEP * i)
		results.append({"player_id": player_ids_in_order[i], "score": score})
	return results
