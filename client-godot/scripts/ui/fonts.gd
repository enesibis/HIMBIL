class_name Fonts
extends RefCounted

## Baloo 2 (başlıklar/butonlar) ve Nunito (gövde metni) — "Sıcak Karnaval"
## tasarım yönünün tipografisi. İkisi de variable font (tek dosyada tüm
## ağırlıklar), Türkçe karakterlerin tamamını içerir.

const BALOO_PATH := "res://assets/fonts/Baloo2.ttf"
const NUNITO_PATH := "res://assets/fonts/Nunito.ttf"

static var _cache: Dictionary = {}


static func baloo(weight: int = 700) -> FontVariation:
	return _variation(BALOO_PATH, weight)


static func nunito(weight: int = 700) -> FontVariation:
	return _variation(NUNITO_PATH, weight)


static func _variation(path: String, weight: int) -> FontVariation:
	var key := "%s:%d" % [path, weight]
	if _cache.has(key):
		return _cache[key]
	var base: FontFile = load(path)
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {"wght": weight}
	_cache[key] = variation
	return variation
