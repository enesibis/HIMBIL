class_name CountdownRing
extends Control

## Tasarımdaki dairesel SVG ilerleme halkasının Godot karşılığı —
## kalan süre oranına göre kırmızı bir yay çizer.

var progress: float = 1.0  # 1.0 = süre dolu, 0.0 = bitti


func set_progress(p: float) -> void:
	progress = clamp(p, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var radius: float = size.x / 2.0 - 8.0
	var center: Vector2 = size / 2.0
	var track_color := Color(Palette.TEXT_PRIMARY.r, Palette.TEXT_PRIMARY.g, Palette.TEXT_PRIMARY.b, 0.1)
	draw_arc(center, radius, 0, TAU, 48, track_color, 10.0, true)
	if progress > 0.0:
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, Palette.RED, 10.0, true)
