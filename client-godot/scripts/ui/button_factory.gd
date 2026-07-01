class_name ButtonFactory
extends RefCounted

## Tasarımdaki "katı basılı buton" hissini üretir: renkli buton yüzeyi +
## altında solid (blursuz) koyu gölge şeridi + üstte cam parlaklığı overlay.
## Döndürülen Control kökü hem gölgeyi hem butonu içerir; iç Button'a
## meta("button") ile erişilir (sinyal bağlamak için).
static func make_cta(
	text: String,
	button_size: Vector2,
	bg_color: Color,
	shadow_bar_color: Color,
	corner_radius: int,
	font_size: int,
	font_color: Color = Color.WHITE
) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(button_size.x, button_size.y + 12)
	wrap.size = wrap.custom_minimum_size

	var shadow := Panel.new()
	shadow.position = Vector2(0, 12)
	shadow.size = button_size
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = shadow_bar_color
	shadow_style.set_corner_radius_all(corner_radius)
	shadow.add_theme_stylebox_override("panel", shadow_style)
	wrap.add_child(shadow)

	var button := Button.new()
	button.text = text
	button.position = Vector2.ZERO
	button.size = button_size
	button.add_theme_font_override("font", Fonts.baloo(800))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(corner_radius)
	style.shadow_size = 18
	style.shadow_color = Color(bg_color.r, bg_color.g, bg_color.b, 0.32)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	wrap.add_child(button)
	wrap.set_meta("button", button)

	var gloss := Panel.new()
	gloss.position = Vector2(0, 0)
	gloss.size = Vector2(button_size.x, button_size.y * 0.5)
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gloss_style := StyleBoxFlat.new()
	gloss_style.bg_color = Color(1, 1, 1, 0.28)
	gloss_style.corner_radius_top_left = corner_radius
	gloss_style.corner_radius_top_right = corner_radius
	gloss.add_theme_stylebox_override("panel", gloss_style)
	wrap.add_child(gloss)

	return wrap


## Basit ikincil/pasif kart-buton (Ana Menü, Zaten bastın vb.) — gölge
## şeridi olmadan, sadece yumuşak gölgeli düz yüzey.
static func make_soft(
	text: String,
	button_size: Vector2,
	bg_color: Color,
	text_color: Color,
	corner_radius: int,
	font_size: int
) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = button_size
	button.size = button_size
	button.add_theme_font_override("font", Fonts.baloo(700))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(corner_radius)
	style.shadow_size = 10
	style.shadow_color = Color(Palette.TEXT_PRIMARY.r, Palette.TEXT_PRIMARY.g, Palette.TEXT_PRIMARY.b, 0.08)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button
