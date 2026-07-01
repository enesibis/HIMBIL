class_name CardView
extends Control

signal tapped

## Tasarımdaki 70x96 kart (402 genişlik referans çerçeve) bu projenin
## 1080 genişlikli tasarım çözünürlüğüne oranlanmış hâli (~x2.7).
const CARD_SIZE := Vector2(188, 258)
const CORNER_RADIUS := 40
const BORDER_WIDTH := 8
const PIP_SIZE := 30.0

var card_data: Dictionary = {}
var is_selected: bool = false

var _panel: Panel
var _icon: CardIcon
var _pip_top: CardIcon
var _pip_bottom: CardIcon


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE / 2

	_panel = Panel.new()
	_panel.position = Vector2.ZERO
	_panel.size = CARD_SIZE
	add_child(_panel)

	_pip_top = CardIcon.new()
	_pip_top.position = Vector2(10, 8)
	_pip_top.size = Vector2(PIP_SIZE, PIP_SIZE)
	_pip_top.modulate = Color(1, 1, 1, 0.45)
	add_child(_pip_top)

	_pip_bottom = CardIcon.new()
	_pip_bottom.position = Vector2(CARD_SIZE.x - 10 - PIP_SIZE, CARD_SIZE.y - 8 - PIP_SIZE)
	_pip_bottom.size = Vector2(PIP_SIZE, PIP_SIZE)
	_pip_bottom.rotation_degrees = 180
	_pip_bottom.pivot_offset = Vector2(PIP_SIZE, PIP_SIZE) / 2
	_pip_bottom.modulate = Color(1, 1, 1, 0.45)
	add_child(_pip_bottom)

	var icon_size := Vector2(104, 104)
	_icon = CardIcon.new()
	_icon.position = (CARD_SIZE - icon_size) / 2.0
	_icon.size = icon_size
	add_child(_icon)

	var button := Button.new()
	button.position = Vector2.ZERO
	button.size = CARD_SIZE
	button.flat = true
	button.pressed.connect(func(): tapped.emit())
	add_child(button)

	if not card_data.is_empty():
		_apply_visual()


func set_card(data: Dictionary) -> void:
	card_data = data
	is_selected = false
	if is_inside_tree():
		_apply_visual()


func set_selected(selected: bool) -> void:
	is_selected = selected
	var target_scale := Vector2(1.06, 1.06) if selected else Vector2(1, 1)
	var tween := create_tween()
	tween.tween_property(self, "scale", target_scale, 0.12).set_trans(Tween.TRANS_BACK)
	if not card_data.is_empty():
		_apply_visual()


func play_arrive_animation(delay: float = 0.0) -> void:
	scale = Vector2(0.4, 0.4)
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.22)


func _apply_visual() -> void:
	var type: String = card_data["object_type"]

	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SURFACE
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_border_width_all(BORDER_WIDTH)
	style.border_color = Palette.RED_LIGHT if is_selected else Palette.RED
	style.shadow_size = 14
	style.shadow_color = Color(Palette.TEXT_PRIMARY.r, Palette.TEXT_PRIMARY.g, Palette.TEXT_PRIMARY.b, 0.12)
	style.shadow_offset = Vector2(0, 6)
	_panel.add_theme_stylebox_override("panel", style)

	_icon.set_type(type)
	_pip_top.set_type(type)
	_pip_bottom.set_type(type)
