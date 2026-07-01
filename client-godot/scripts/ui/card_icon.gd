class_name CardIcon
extends Control

## Basit prosedürel meyve ikonları — "Sıcak Karnaval" tasarımında kart
## yüzü emoji placeholder'dı; burada onun yerine kendi rengiyle çizilen
## küçük vektör ikonlar kullanıyoruz (dış görsel varlık gerekmeden).

var object_type: String = ""


func set_type(t: String) -> void:
	object_type = t
	queue_redraw()


func _draw() -> void:
	var s := size
	var c := s / 2.0
	var col: Color = Palette.FRUIT_COLORS.get(object_type, Palette.TEXT_SECONDARY)

	match object_type:
		"elma":
			draw_circle(Vector2(c.x, c.y + 6), s.x * 0.30, col)
			draw_rect(Rect2(c.x - 4, c.y - s.x * 0.30 - 12, 8, 16), col)
		"armut":
			draw_circle(Vector2(c.x, c.y + 14), s.x * 0.28, col)
			draw_circle(Vector2(c.x, c.y - 10), s.x * 0.18, col)
		"muz":
			draw_arc(Vector2(c.x, c.y + 26), s.x * 0.5, deg_to_rad(200), deg_to_rad(340), 24, col, 16.0, true)
		"cilek":
			var pts := PackedVector2Array([
				Vector2(c.x, c.y + s.y * 0.32),
				Vector2(c.x - s.x * 0.26, c.y - s.y * 0.06),
				Vector2(c.x + s.x * 0.26, c.y - s.y * 0.06),
			])
			draw_colored_polygon(pts, col)
			draw_rect(Rect2(c.x - 10, c.y - s.y * 0.20, 20, 10), Palette.GREEN)
