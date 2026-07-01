extends Control

## "Sıcak Karnaval" (Yön 1a) tasarım diline göre kurulmuş arayüz.
## Kaynak: MD dosyasından uygulama tasarımı/design_handoff_himbil_sicak_karnaval/

const PLAYER_LABELS := {
	"human": "Sen",
	"bot_north": "Mehmet",
	"bot_west": "Zeynep",
	"bot_east": "Ayşe",
}

const CANVAS_SIZE := Vector2(1080, 1920)

var _menu_layer: Control
var _game_layer: Control
var _game_over_layer: Control

var _controller: GameController
var _human_card_views: Array = []
var _bot_slots: Dictionary = {}
var _phase_label: Label
var _countdown_ring: CountdownRing
var _slam_wrap: Control
var _slam_button: Button
var _slam_pulse_tween: Tween
var _human_score_label: Label
var _hand_row: HBoxContainer

var _toast_panel: Panel
var _toast_label: Label

var _game_over_trophy_label: Label
var _game_over_title: Label
var _game_over_list: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_menu_layer()
	_build_game_layer()
	_build_game_over_layer()
	_build_toast()
	_show_menu()


# ------------------------------------------------------------ Background ----

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG_CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_add_radial_blob(Palette.MUSTARD, 0.22, Vector2(0.14, 0.06), 950)
	_add_radial_blob(Palette.RED, 0.14, Vector2(0.92, 0.18), 850)
	_add_radial_blob(Palette.GREEN, 0.08, Vector2(0.5, 1.0), 1100)


func _add_radial_blob(color: Color, alpha: float, center_ratio: Vector2, diameter: float) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(color.r, color.g, color.b, alpha),
		Color(color.r, color.g, color.b, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = int(diameter)
	tex.height = int(diameter)

	var rect := TextureRect.new()
	rect.texture = tex
	rect.size = Vector2(diameter, diameter)
	rect.position = Vector2(
		CANVAS_SIZE.x * center_ratio.x - diameter / 2.0,
		CANVAS_SIZE.y * center_ratio.y - diameter / 2.0
	)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


# ---------------------------------------------------------------- Toast ----

func _build_toast() -> void:
	_toast_panel = Panel.new()
	_toast_panel.size = Vector2(820, 80)
	_toast_panel.position = Vector2((CANVAS_SIZE.x - 820) / 2.0, 330)
	_toast_panel.pivot_offset = Vector2(410, 40)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.RED
	style.set_corner_radius_all(32)
	style.shadow_size = 16
	style.shadow_color = Color(Palette.RED.r, Palette.RED.g, Palette.RED.b, 0.4)
	_toast_panel.add_theme_stylebox_override("panel", style)
	_toast_panel.modulate = Color(1, 1, 1, 0)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_override("font", Fonts.baloo(700))
	_toast_label.add_theme_font_size_override("font_size", 26)
	_toast_label.add_theme_color_override("font_color", Color.WHITE)
	_toast_panel.add_child(_toast_label)


func _show_toast(text: String) -> void:
	var base_x := (CANVAS_SIZE.x - 820) / 2.0
	_toast_label.text = text
	_toast_panel.position.x = base_x
	_toast_panel.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_property(_toast_panel, "position:x", base_x - 10, 0.05)
	tween.tween_property(_toast_panel, "position:x", base_x + 10, 0.05)
	tween.tween_property(_toast_panel, "position:x", base_x, 0.05)
	tween.tween_interval(1.2)
	tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.4)


# ---------------------------------------------------------------- Menu ----

func _build_menu_layer() -> void:
	_menu_layer = Control.new()
	_menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu_layer)

	# Header: logo rozeti + başlık, sağda avatar
	var logo := Panel.new()
	logo.position = Vector2(60, 60)
	logo.size = Vector2(70, 70)
	var logo_style := StyleBoxFlat.new()
	logo_style.bg_color = Palette.RED_LIGHT
	logo_style.set_corner_radius_all(22)
	logo_style.shadow_size = 10
	logo_style.shadow_color = Color(Palette.RED.r, Palette.RED.g, Palette.RED.b, 0.35)
	logo.add_theme_stylebox_override("panel", logo_style)
	_menu_layer.add_child(logo)

	var logo_label := Label.new()
	logo_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo_label.add_theme_font_override("font", Fonts.baloo(800))
	logo_label.add_theme_font_size_override("font_size", 30)
	logo_label.add_theme_color_override("font_color", Color.WHITE)
	logo_label.text = "H"
	logo.add_child(logo_label)

	var title := Label.new()
	title.text = "Hımbıl"
	title.add_theme_font_override("font", Fonts.baloo(800))
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	title.position = Vector2(148, 68)
	title.size = Vector2(400, 60)
	_menu_layer.add_child(title)

	var avatar_ring := Panel.new()
	avatar_ring.position = Vector2(CANVAS_SIZE.x - 60 - 90, 55)
	avatar_ring.size = Vector2(90, 90)
	var avatar_ring_style := StyleBoxFlat.new()
	avatar_ring_style.bg_color = Palette.MUSTARD
	avatar_ring_style.set_corner_radius_all(45)
	avatar_ring_style.shadow_size = 10
	avatar_ring_style.shadow_color = Color(Palette.RED.r, Palette.RED.g, Palette.RED.b, 0.3)
	avatar_ring.add_theme_stylebox_override("panel", avatar_ring_style)
	_menu_layer.add_child(avatar_ring)

	var avatar_inner := Panel.new()
	avatar_inner.position = Vector2(5, 5)
	avatar_inner.size = Vector2(80, 80)
	var avatar_inner_style := StyleBoxFlat.new()
	avatar_inner_style.bg_color = Palette.SURFACE
	avatar_inner_style.set_corner_radius_all(40)
	avatar_inner.add_theme_stylebox_override("panel", avatar_inner_style)
	avatar_ring.add_child(avatar_inner)

	var avatar_label := Label.new()
	avatar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_label.add_theme_font_override("font", Fonts.baloo(800))
	avatar_label.add_theme_font_size_override("font_size", 30)
	avatar_label.add_theme_color_override("font_color", Palette.RED)
	avatar_label.text = "S"
	avatar_inner.add_child(avatar_label)

	# Karşılama
	var hello := Label.new()
	hello.text = "Merhaba,"
	hello.add_theme_font_override("font", Fonts.nunito(700))
	hello.add_theme_font_size_override("font_size", 28)
	hello.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	hello.position = Vector2(60, 200)
	hello.size = Vector2(700, 40)
	_menu_layer.add_child(hello)

	var greeting := Label.new()
	greeting.text = "Bugün Hımbıl var!"
	greeting.add_theme_font_override("font", Fonts.baloo(700))
	greeting.add_theme_font_size_override("font_size", 48)
	greeting.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	greeting.position = Vector2(60, 244)
	greeting.size = Vector2(960, 70)
	_menu_layer.add_child(greeting)

	# HIZLI OYNA CTA
	var cta_size := Vector2(960, 210)
	var cta_pos := Vector2(60, 360)
	var cta_shadow := Panel.new()
	cta_shadow.position = cta_pos + Vector2(0, 24)
	cta_shadow.size = cta_size
	var cta_shadow_style := StyleBoxFlat.new()
	cta_shadow_style.bg_color = Palette.RED_SHADOW
	cta_shadow_style.set_corner_radius_all(56)
	cta_shadow.add_theme_stylebox_override("panel", cta_shadow_style)
	_menu_layer.add_child(cta_shadow)

	var cta_button := Button.new()
	cta_button.position = cta_pos
	cta_button.size = cta_size
	cta_button.flat = true
	var cta_style := StyleBoxFlat.new()
	cta_style.bg_color = Palette.RED_LIGHT
	cta_style.set_corner_radius_all(56)
	cta_style.shadow_size = 26
	cta_style.shadow_color = Color(Palette.RED.r, Palette.RED.g, Palette.RED.b, 0.32)
	cta_button.add_theme_stylebox_override("normal", cta_style)
	cta_button.add_theme_stylebox_override("hover", cta_style)
	cta_button.add_theme_stylebox_override("pressed", cta_style)
	cta_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	cta_button.pressed.connect(_on_play_pressed)
	_menu_layer.add_child(cta_button)

	var cta_gloss := Panel.new()
	cta_gloss.position = cta_pos
	cta_gloss.size = Vector2(cta_size.x, cta_size.y * 0.5)
	cta_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cta_gloss_style := StyleBoxFlat.new()
	cta_gloss_style.bg_color = Color(1, 1, 1, 0.3)
	cta_gloss_style.corner_radius_top_left = 56
	cta_gloss_style.corner_radius_top_right = 56
	cta_gloss.add_theme_stylebox_override("panel", cta_gloss_style)
	_menu_layer.add_child(cta_gloss)

	var cta_title := Label.new()
	cta_title.text = "▶  HIZLI OYNA"
	cta_title.add_theme_font_override("font", Fonts.baloo(800))
	cta_title.add_theme_font_size_override("font_size", 44)
	cta_title.add_theme_color_override("font_color", Color.WHITE)
	cta_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cta_title.position = cta_pos + Vector2(0, 66)
	cta_title.size = Vector2(cta_size.x, 60)
	cta_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_layer.add_child(cta_title)

	var cta_subtitle := Label.new()
	cta_subtitle.text = "Rastgele oyuncularla eşleş"
	cta_subtitle.add_theme_font_override("font", Fonts.nunito(700))
	cta_subtitle.add_theme_font_size_override("font_size", 24)
	cta_subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.88))
	cta_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cta_subtitle.position = cta_pos + Vector2(0, 132)
	cta_subtitle.size = Vector2(cta_size.x, 40)
	cta_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_layer.add_child(cta_subtitle)

	# Ayraç
	var divider_y := cta_pos.y + cta_size.y + 24 + 50
	var divider_label := Label.new()
	divider_label.text = "VEYA ÖZEL ODA"
	divider_label.add_theme_font_override("font", Fonts.nunito(800))
	divider_label.add_theme_font_size_override("font_size", 20)
	divider_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	divider_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	divider_label.position = Vector2(0, divider_y)
	divider_label.size = Vector2(CANVAS_SIZE.x, 30)
	_menu_layer.add_child(divider_label)

	# İkincil kartlar: Oda Kur / Kodla Katıl (henüz çok oyunculu yok)
	var secondary_y := divider_y + 50
	var secondary_size := Vector2(466, 190)
	_menu_layer.add_child(_build_secondary_card(
		Vector2(60, secondary_y), secondary_size, "Oda Kur", Palette.MUSTARD
	))
	_menu_layer.add_child(_build_secondary_card(
		Vector2(60 + secondary_size.x + 28, secondary_y), secondary_size, "Kodla Katıl", Palette.BLUE
	))


func _build_secondary_card(pos: Vector2, card_size: Vector2, label_text: String, icon_color: Color) -> Control:
	var button := Button.new()
	button.position = pos
	button.size = card_size
	button.flat = true
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SURFACE
	style.set_corner_radius_all(30)
	style.set_border_width_all(3)
	style.border_color = Color(Palette.TEXT_PRIMARY.r, Palette.TEXT_PRIMARY.g, Palette.TEXT_PRIMARY.b, 0.05)
	style.shadow_size = 14
	style.shadow_color = Color(Palette.TEXT_PRIMARY.r, Palette.TEXT_PRIMARY.g, Palette.TEXT_PRIMARY.b, 0.08)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(_on_coming_soon_pressed)

	var badge := Panel.new()
	badge.position = Vector2((card_size.x - 76) / 2.0, 26)
	badge.size = Vector2(76, 76)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = icon_color
	badge_style.set_corner_radius_all(26)
	badge_style.shadow_size = 8
	badge_style.shadow_color = Color(icon_color.r, icon_color.g, icon_color.b, 0.35)
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_override("font", Fonts.baloo(700))
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 118)
	label.size = Vector2(card_size.x, 40)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

	return button


func _on_coming_soon_pressed() -> void:
	_show_toast("Çok yakında! (çok oyunculu Aşama 3'te)")


func _on_play_pressed() -> void:
	_start_new_game()
	_show_game()


# ---------------------------------------------------------------- Game ----

func _build_game_layer() -> void:
	_game_layer = Control.new()
	_game_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_game_layer)

	var menu_button := ButtonFactory.make_soft("< Menü", Vector2(140, 60), Palette.SURFACE, Palette.TEXT_PRIMARY, 24, 18)
	menu_button.position = Vector2(30, 30)
	menu_button.pressed.connect(_on_return_to_menu_pressed)
	_game_layer.add_child(menu_button)

	var opponents_row := HBoxContainer.new()
	opponents_row.alignment = BoxContainer.ALIGNMENT_CENTER
	opponents_row.add_theme_constant_override("separation", 40)
	opponents_row.position = Vector2(0, 120)
	opponents_row.size = Vector2(CANVAS_SIZE.x, 190)
	_game_layer.add_child(opponents_row)

	for bot_id in ["bot_west", "bot_north", "bot_east"]:
		var slot := PlayerSlot.new()
		opponents_row.add_child(slot)
		_bot_slots[bot_id] = slot

	_add_radial_blob(Palette.RED, 0.16, Vector2(0.5, 0.29), 520)

	var ring_wrap := Panel.new()
	ring_wrap.position = Vector2((CANVAS_SIZE.x - 180) / 2.0, 350)
	ring_wrap.size = Vector2(180, 180)
	var ring_wrap_style := StyleBoxFlat.new()
	ring_wrap_style.bg_color = Palette.SURFACE
	ring_wrap_style.set_corner_radius_all(90)
	ring_wrap_style.shadow_size = 14
	ring_wrap_style.shadow_color = Color(Palette.TEXT_PRIMARY.r, Palette.TEXT_PRIMARY.g, Palette.TEXT_PRIMARY.b, 0.14)
	ring_wrap.add_theme_stylebox_override("panel", ring_wrap_style)
	_game_layer.add_child(ring_wrap)

	_countdown_ring = CountdownRing.new()
	_countdown_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring_wrap.add_child(_countdown_ring)

	_phase_label = Label.new()
	_phase_label.add_theme_font_override("font", Fonts.nunito(800))
	_phase_label.add_theme_font_size_override("font_size", 26)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.position = Vector2(0, 560)
	_phase_label.size = Vector2(CANVAS_SIZE.x, 40)
	_game_layer.add_child(_phase_label)

	_hand_row = HBoxContainer.new()
	_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_row.add_theme_constant_override("separation", 18)
	_hand_row.position = Vector2(0, 780)
	_hand_row.size = Vector2(CANVAS_SIZE.x, 270)
	_game_layer.add_child(_hand_row)

	for _i in range(4):
		var cv := CardView.new()
		_hand_row.add_child(cv)
		cv.tapped.connect(_on_human_card_tapped.bind(cv))
		_human_card_views.append(cv)

	_slam_wrap = ButtonFactory.make_cta("HIMBIL!", Vector2(300, 300), Palette.RED_LIGHT, Palette.RED_SHADOW, 150, 40)
	_slam_wrap.position = Vector2((CANVAS_SIZE.x - 300) / 2.0, 1150)
	_slam_wrap.pivot_offset = _slam_wrap.size / 2.0
	_slam_button = _slam_wrap.get_meta("button")
	_slam_button.pressed.connect(_on_slam_pressed)
	_game_layer.add_child(_slam_wrap)

	_human_score_label = Label.new()
	_human_score_label.add_theme_font_override("font", Fonts.baloo(700))
	_human_score_label.add_theme_font_size_override("font_size", 26)
	_human_score_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_human_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_human_score_label.position = Vector2(0, 1490)
	_human_score_label.size = Vector2(CANVAS_SIZE.x, 40)
	_game_layer.add_child(_human_score_label)


func _start_new_game() -> void:
	if _controller:
		_controller.queue_free()
	_controller = GameController.new()
	_controller.phase_changed.connect(_on_phase_changed)
	_controller.hands_updated.connect(_on_hands_updated)
	_controller.countdown_tick.connect(_on_countdown_tick)
	_controller.slam_attempt_recorded.connect(_on_slam_attempt_recorded)
	_controller.false_slam_penalty.connect(_on_false_slam_penalty)
	_controller.round_scored.connect(_on_round_scored)
	_controller.game_over.connect(_on_game_over)
	add_child(_controller)


func _on_return_to_menu_pressed() -> void:
	if _controller:
		_controller.queue_free()
		_controller = null
	_show_menu()


func _on_phase_changed(phase: String) -> void:
	match phase:
		"swapping":
			_phase_label.text = "İşine yaramayan kartı seç, komşuna ver"
			_phase_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
			_stop_slam_pulse()
		"slamWindow":
			_phase_label.text = "4'lün tamam — HIMBIL'e bas!"
			_phase_label.add_theme_color_override("font_color", Palette.GREEN)
			_pulse_slam_button()
		"scoring":
			_phase_label.text = "Puanlar hesaplanıyor..."
			_phase_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
			_stop_slam_pulse()


func _on_hands_updated(hands: Array, changed_slot: int) -> void:
	var human_hand: Array = hands[0]
	for i in range(4):
		_human_card_views[i].set_card(human_hand[i])
		if changed_slot == -1:
			_human_card_views[i].play_arrive_animation(i * 0.06)
		elif i == changed_slot:
			_human_card_views[i].play_arrive_animation(0.0)

	for key in _bot_slots.keys():
		_bot_slots[key].set_name_text(PLAYER_LABELS.get(key, key))
		_bot_slots[key].set_score(_controller.scores[key])
	_human_score_label.text = "Puanın: %d" % _controller.scores[GameController.HUMAN_ID]


func _on_countdown_tick(seconds_left: float) -> void:
	var max_duration: float = (
		GameController.SLAM_WINDOW_DURATION if _controller.phase == "slamWindow"
		else GameController.SWAP_TICK_DURATION
	)
	_countdown_ring.set_progress(seconds_left / max_duration)


func _on_human_card_tapped(cv: CardView) -> void:
	if _controller.phase != "swapping":
		return
	for other in _human_card_views:
		other.set_selected(other == cv)
	_controller.submit_human_choice(cv.card_data["id"])


func _on_slam_pressed() -> void:
	_bounce_slam_button()
	var result: String = _controller.submit_human_slam()
	if result == "already":
		_show_toast("Zaten bastın")
	# "recorded" -> feedback slam_attempt_recorded'dan gelir
	# "false_start" -> feedback false_slam_penalty'den gelir


func _on_slam_attempt_recorded(player_id: String) -> void:
	if player_id == GameController.HUMAN_ID:
		_show_toast("Sıradasın!")
	elif _bot_slots.has(player_id):
		_bot_slots[player_id].pulse()


func _on_false_slam_penalty(player_id: String, new_score: int) -> void:
	if player_id == GameController.HUMAN_ID:
		_human_score_label.text = "Puanın: %d" % new_score
		_show_toast("Erken bastın! Ceza puanı")
		_show_score_popup(Rules.FALSE_SLAM_PENALTY)


func _on_round_scored(results: Array, scores: Dictionary) -> void:
	_human_score_label.text = "Puanın: %d" % scores[GameController.HUMAN_ID]
	for key in _bot_slots.keys():
		_bot_slots[key].set_score(scores[key])

	for r in results:
		if r["player_id"] == GameController.HUMAN_ID:
			_show_score_popup(r["score"])


func _show_score_popup(delta: int) -> void:
	var label := Label.new()
	label.text = ("+%d" % delta) if delta >= 0 else str(delta)
	label.add_theme_font_override("font", Fonts.baloo(800))
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Palette.GREEN if delta >= 0 else Palette.RED)
	label.position = Vector2(0, 1490)
	label.size = Vector2(CANVAS_SIZE.x, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", 1440, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.tween_callback(label.queue_free)


func _bounce_slam_button() -> void:
	var was_pulsing := _slam_pulse_tween != null
	_stop_slam_pulse()
	var tween := create_tween()
	tween.tween_property(_slam_wrap, "scale", Vector2(0.9, 0.9), 0.06)
	tween.tween_property(_slam_wrap, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BACK)
	if was_pulsing:
		tween.tween_callback(func():
			if _controller and _controller.phase == "slamWindow":
				_pulse_slam_button()
		)


func _pulse_slam_button() -> void:
	_stop_slam_pulse()
	_slam_wrap.scale = Vector2.ONE
	_slam_pulse_tween = create_tween()
	_slam_pulse_tween.set_loops()
	_slam_pulse_tween.tween_property(_slam_wrap, "scale", Vector2(1.06, 1.06), 0.4).set_trans(Tween.TRANS_SINE)
	_slam_pulse_tween.tween_property(_slam_wrap, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_SINE)


func _stop_slam_pulse() -> void:
	if _slam_pulse_tween:
		_slam_pulse_tween.kill()
		_slam_pulse_tween = null
	_slam_wrap.scale = Vector2.ONE


# ------------------------------------------------------------ Game Over ----

func _build_game_over_layer() -> void:
	_game_over_layer = Control.new()
	_game_over_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_game_over_layer)

	var dim := ColorRect.new()
	dim.color = Color(Palette.TEXT_PRIMARY.r, Palette.TEXT_PRIMARY.g, Palette.TEXT_PRIMARY.b, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_layer.add_child(dim)

	for dot in [
		{"pos": Vector2(54, 173), "size": 49.0, "color": Palette.MUSTARD},
		{"pos": Vector2(CANVAS_SIZE.x - 70 - 35, 297), "size": 35.0, "color": Palette.GREEN},
		{"pos": Vector2(CANVAS_SIZE.x - 173 - 24, 97), "size": 24.0, "color": Palette.BLUE},
		{"pos": Vector2(135, 405), "size": 27.0, "color": Palette.RED},
	]:
		var confetti := Panel.new()
		confetti.position = dot["pos"]
		confetti.size = Vector2(dot["size"], dot["size"])
		var confetti_style := StyleBoxFlat.new()
		confetti_style.bg_color = Color(dot["color"].r, dot["color"].g, dot["color"].b, 0.55)
		confetti_style.set_corner_radius_all(int(dot["size"] / 2.0))
		confetti.add_theme_stylebox_override("panel", confetti_style)
		confetti.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_game_over_layer.add_child(confetti)

	var trophy := Panel.new()
	trophy.position = Vector2((CANVAS_SIZE.x - 190) / 2.0, 220)
	trophy.size = Vector2(190, 190)
	var trophy_style := StyleBoxFlat.new()
	trophy_style.bg_color = Palette.MUSTARD
	trophy_style.set_corner_radius_all(95)
	trophy_style.shadow_size = 22
	trophy_style.shadow_color = Color(Palette.MUSTARD.r, Palette.MUSTARD.g, Palette.MUSTARD.b, 0.45)
	trophy.add_theme_stylebox_override("panel", trophy_style)
	_game_over_layer.add_child(trophy)

	_game_over_trophy_label = Label.new()
	_game_over_trophy_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_trophy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_trophy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_trophy_label.add_theme_font_override("font", Fonts.baloo(800))
	_game_over_trophy_label.add_theme_font_size_override("font_size", 80)
	_game_over_trophy_label.add_theme_color_override("font_color", Color.WHITE)
	trophy.add_child(_game_over_trophy_label)

	_start_glow_pulse(trophy)

	_game_over_title = Label.new()
	_game_over_title.add_theme_font_override("font", Fonts.baloo(800))
	_game_over_title.add_theme_font_size_override("font_size", 48)
	_game_over_title.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_title.position = Vector2(0, 430)
	_game_over_title.size = Vector2(CANVAS_SIZE.x, 60)
	_game_over_layer.add_child(_game_over_title)

	_game_over_list = VBoxContainer.new()
	_game_over_list.add_theme_constant_override("separation", 14)
	_game_over_list.position = Vector2(80, 540)
	_game_over_list.size = Vector2(CANVAS_SIZE.x - 160, 400)
	_game_over_layer.add_child(_game_over_list)

	var replay := ButtonFactory.make_cta("TEKRAR OYNA", Vector2(460, 130), Palette.RED_LIGHT, Palette.RED_SHADOW, 34, 30)
	replay.position = Vector2((CANVAS_SIZE.x - 460) / 2.0, 1000)
	(replay.get_meta("button") as Button).pressed.connect(_on_play_again_pressed)
	_game_over_layer.add_child(replay)

	var back_menu := ButtonFactory.make_soft("Ana Menü", Vector2(460, 90), Palette.SURFACE, Palette.TEXT_PRIMARY, 28, 24)
	back_menu.position = Vector2((CANVAS_SIZE.x - 460) / 2.0, 1160)
	back_menu.pressed.connect(_on_game_over_menu_pressed)
	_game_over_layer.add_child(back_menu)


func _start_glow_pulse(node: Control) -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(node, "modulate", Color(1.08, 1.08, 1.0), 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate", Color(1, 1, 1), 1.0).set_trans(Tween.TRANS_SINE)


func _on_game_over(winner_id: String, scores: Dictionary) -> void:
	if winner_id == GameController.HUMAN_ID:
		_game_over_title.text = "Kazandın!"
	else:
		_game_over_title.text = "%s kazandı!" % PLAYER_LABELS.get(winner_id, winner_id)
	_game_over_trophy_label.text = PLAYER_LABELS.get(winner_id, winner_id).substr(0, 1).to_upper()

	for child in _game_over_list.get_children():
		child.queue_free()

	var sorted_ids: Array = scores.keys()
	sorted_ids.sort_custom(func(a, b): return scores[a] > scores[b])
	var rank_colors := [Palette.RANK_GOLD, Palette.RANK_SILVER, Palette.RANK_BRONZE, Palette.RANK_NEUTRAL]

	for i in range(sorted_ids.size()):
		var pid: String = sorted_ids[i]
		_game_over_list.add_child(_build_rank_row(i + 1, PLAYER_LABELS.get(pid, pid), scores[pid], rank_colors[min(i, rank_colors.size() - 1)]))

	_show_game_over()


func _build_rank_row(rank: int, name: String, score: int, badge_color: Color) -> Control:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, 84)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Palette.SURFACE
	row_style.set_corner_radius_all(20)
	row_style.shadow_size = 10
	row_style.shadow_color = Color(Palette.TEXT_PRIMARY.r, Palette.TEXT_PRIMARY.g, Palette.TEXT_PRIMARY.b, 0.08)
	row.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 20
	hbox.offset_right = -20
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(48, 48)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = badge_color
	badge_style.set_corner_radius_all(24)
	badge.add_theme_stylebox_override("panel", badge_style)
	var badge_label := Label.new()
	badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_override("font", Fonts.nunito(800))
	badge_label.add_theme_font_size_override("font_size", 20)
	badge_label.add_theme_color_override("font_color", Color.WHITE)
	badge_label.text = str(rank)
	badge.add_child(badge_label)
	hbox.add_child(badge)

	var name_label := Label.new()
	name_label.text = name
	name_label.add_theme_font_override("font", Fonts.baloo(700))
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var score_label := Label.new()
	score_label.text = str(score)
	score_label.add_theme_font_override("font", Fonts.baloo(800))
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.add_theme_color_override("font_color", Palette.GREEN)
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(score_label)

	return row


func _on_play_again_pressed() -> void:
	_start_new_game()
	_show_game()


func _on_game_over_menu_pressed() -> void:
	if _controller:
		_controller.queue_free()
		_controller = null
	_show_menu()


# ------------------------------------------------------------ Layer FX ----

func _show_menu() -> void:
	_menu_layer.visible = true
	_game_layer.visible = false
	_game_over_layer.visible = false


func _show_game() -> void:
	_menu_layer.visible = false
	_game_layer.visible = true
	_game_over_layer.visible = false


func _show_game_over() -> void:
	_menu_layer.visible = false
	_game_layer.visible = true
	_game_over_layer.visible = true
