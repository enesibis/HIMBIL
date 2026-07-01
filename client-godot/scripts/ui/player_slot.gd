class_name PlayerSlot
extends Control

const SLOT_WIDTH := 200
const AVATAR_SIZE := 108
const RING_WIDTH := 5

var _name_label: Label
var _score_label: Label
var _avatar_ring: Panel
var _avatar_inner: Panel
var _avatar_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_WIDTH, 190)

	_avatar_ring = Panel.new()
	_avatar_ring.position = Vector2((SLOT_WIDTH - AVATAR_SIZE) / 2.0, 0)
	_avatar_ring.size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Palette.BLUE
	ring_style.set_corner_radius_all(AVATAR_SIZE / 2)
	ring_style.shadow_size = 10
	ring_style.shadow_color = Color(Palette.BLUE.r, Palette.BLUE.g, Palette.BLUE.b, 0.35)
	_avatar_ring.add_theme_stylebox_override("panel", ring_style)
	add_child(_avatar_ring)

	_avatar_inner = Panel.new()
	_avatar_inner.position = Vector2(RING_WIDTH, RING_WIDTH)
	_avatar_inner.size = Vector2(AVATAR_SIZE - RING_WIDTH * 2, AVATAR_SIZE - RING_WIDTH * 2)
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Palette.SURFACE
	inner_style.set_corner_radius_all((AVATAR_SIZE - RING_WIDTH * 2) / 2)
	_avatar_inner.add_theme_stylebox_override("panel", inner_style)
	_avatar_ring.add_child(_avatar_inner)

	_avatar_label = Label.new()
	_avatar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avatar_label.add_theme_font_override("font", Fonts.baloo(800))
	_avatar_label.add_theme_font_size_override("font_size", 36)
	_avatar_label.add_theme_color_override("font_color", Palette.BLUE)
	_avatar_inner.add_child(_avatar_label)

	_name_label = Label.new()
	_name_label.position = Vector2(0, AVATAR_SIZE + 10)
	_name_label.size = Vector2(SLOT_WIDTH, 30)
	_name_label.add_theme_font_override("font", Fonts.nunito(700))
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)

	_score_label = Label.new()
	_score_label.position = Vector2(0, AVATAR_SIZE + 40)
	_score_label.size = Vector2(SLOT_WIDTH, 26)
	_score_label.add_theme_font_override("font", Fonts.baloo(700))
	_score_label.add_theme_font_size_override("font_size", 16)
	_score_label.add_theme_color_override("font_color", Palette.RED)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_score_label)


func set_name_text(text: String) -> void:
	_name_label.text = text
	_avatar_label.text = text.substr(0, 1).to_upper()


func set_score(value: int) -> void:
	_score_label.text = "%d puan" % value


func pulse() -> void:
	var tween := create_tween()
	tween.tween_property(_avatar_ring, "modulate", Palette.MUSTARD_LIGHT, 0.15)
	tween.tween_property(_avatar_ring, "modulate", Color(1, 1, 1), 0.35)
