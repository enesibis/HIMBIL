class_name BotAI
extends RefCounted

## Basit bot yapay zekası: elindeki en az tekrarlayan (en az işe yarayan)
## türden bir kartı vermeyi seçer, böylece kalan kartlarla 4'lüye
## yaklaşmaya çalışır. Rakip elini bilmediği için sadece kendi eline bakar.
static func decide_card_to_pass(hand: Array) -> int:
	var counts: Dictionary = {}
	for card in hand:
		var t = card["object_type"]
		counts[t] = counts.get(t, 0) + 1

	var min_count := 99
	for t in counts.keys():
		min_count = min(min_count, counts[t])

	var candidates: Array = []
	for card in hand:
		if counts[card["object_type"]] == min_count:
			candidates.append(card)

	return candidates[randi() % candidates.size()]["id"]


## Bot elinde gerçekten 4'lü varsa, HIMBIL'e basmadan önce insansı bir
## reaksiyon gecikmesi (saniye) döner.
static func decide_slam_delay() -> float:
	return randf_range(0.35, 1.3)
