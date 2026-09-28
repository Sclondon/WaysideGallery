class_name Hud
extends CanvasLayer
## Everything drawn over the 3D view: the welcome card, crosshair, "look closer" prompt,
## the wall-text card shown while viewing a piece, touch joystick and fades.

signal prev_pressed
signal next_pressed
signal back_pressed

const STICK_RADIUS := 70.0

var touch_mode := false

var _root := Control.new()
var _intro := ColorRect.new()
var _intro_action := Label.new()
var _intro_keys := Label.new()
var _cross := Control.new()
var _prompt := PanelContainer.new()
var _prompt_title := Label.new()
var _prompt_details := Label.new()
var _prompt_hint := Label.new()
var _card := PanelContainer.new()
var _card_count := Label.new()
var _card_title := Label.new()
var _card_details := Label.new()
var _card_desc := Label.new()
var _card_scroll := ScrollContainer.new()
var _card_keys := Label.new()
var _hint := Label.new()
var _mouse_hint := Label.new()
var _stick := Control.new()
var _fade := ColorRect.new()

var _stick_on := false
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _space := Vector2.ONE
var _pulse := 0.0


func _ready() -> void:
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)

	_build_crosshair()
	_build_prompt()
	_build_card()
	_build_hints()
	_build_stick()
	_build_intro()

	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

	get_viewport().size_changed.connect(_layout_card)
	_layout_card()


func _process(delta: float) -> void:
	_pulse += delta
	if _intro.visible:
		_intro_action.modulate.a = 0.65 + 0.35 * sin(_pulse * 3.0)


# --- public -------------------------------------------------------------------

func set_touch(on: bool) -> void:
	touch_mode = on
	_intro_action.text = "Tap anywhere to enter" if on else "Click anywhere to enter"
	_intro_keys.text = _controls_text()
	_hint.text = _controls_text()
	_prompt_hint.text = "Tap it to look closer" if on else "Press E or click to look closer"
	_card_keys.visible = not on
	_cross.visible = not on and not _card.visible
	_stick.queue_redraw()


func hide_intro() -> void:
	var t := create_tween()
	t.tween_property(_intro, "modulate:a", 0.0, 0.6)
	t.tween_callback(_intro.hide)
	_hint.modulate.a = 1.0
	_hint.show()
	var h := create_tween()
	h.tween_interval(10.0)
	h.tween_property(_hint, "modulate:a", 0.0, 1.5)
	h.tween_callback(_hint.hide)


func show_prompt(piece: ArtPiece) -> void:
	if piece == null:
		_prompt.hide()
		return
	_prompt_title.text = piece.caption()
	_prompt_details.text = piece.details()
	_prompt_details.visible = not piece.details().is_empty()
	_prompt.show()


func show_mouse_hint(on: bool) -> void:
	_mouse_hint.visible = on and not touch_mode


func show_card(piece: ArtPiece, count: int) -> void:
	_card_count.text = "%d  /  %d" % [piece.index + 1, count]
	_card_title.text = piece.title
	var details := PackedStringArray()
	for bit in [piece.artist, piece.year, piece.medium]:
		if not bit.is_empty():
			details.append(bit)
	_card_details.text = "  ·  ".join(details)
	_card_details.visible = not details.is_empty()
	_card_desc.text = piece.description
	_card_scroll.scroll_vertical = 0
	_prompt.hide()
	_cross.hide()
	if not _card.visible:
		_card.modulate.a = 0.0
		_card.show()
		create_tween().tween_property(_card, "modulate:a", 1.0, 0.4)


func hide_card() -> void:
	_card.hide()
	_cross.visible = not touch_mode


## Fraction of the screen (width, height) left free for the picture beside the card.
func free_space() -> Vector2:
	return _space


## Fade to black, call `midway`, fade back in.
func fade_through(midway: Callable) -> Tween:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.25)
	t.tween_callback(midway)
	t.tween_property(_fade, "color:a", 0.0, 0.35)
	return t


func set_stick(on: bool, origin := Vector2.ZERO, pos := Vector2.ZERO) -> void:
	_stick_on = on
	_stick_origin = origin
	_stick_pos = pos
	_stick.queue_redraw()


# --- building -----------------------------------------------------------------

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Style.sans(400)
	t.default_font_size = 20
	t.set_color("font_color", "Label", Style.INK)

	var card := StyleBoxFlat.new()
	card.bg_color = Color(Style.PAPER, 0.97)
	card.set_corner_radius_all(4)
	card.set_content_margin_all(26)
	card.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	card.shadow_size = 14
	t.set_stylebox("panel", "PanelContainer", card)

	for state in ["normal", "hover", "pressed", "focus"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": Color(0, 0, 0, 0.0), "hover": Color(0, 0, 0, 0.06),
			"pressed": Color(0, 0, 0, 0.12), "focus": Color(0, 0, 0, 0.0)}[state]
		b.border_color = Color(Style.INK, 0.35)
		b.set_border_width_all(1)
		b.set_corner_radius_all(3)
		b.content_margin_left = 18
		b.content_margin_right = 18
		b.content_margin_top = 8
		b.content_margin_bottom = 8
		t.set_stylebox(state, "Button", b)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Style.INK)
	t.set_font_size("font_size", "Button", 18)
	return t


func _label(target: Label, font: Font, size: int, colour: Color, parent: Control) -> Label:
	target.add_theme_font_override("font", font)
	target.add_theme_font_size_override("font_size", size)
	target.add_theme_color_override("font_color", colour)
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(target)
	return target


func _build_crosshair() -> void:
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(func() -> void:
		_cross.draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.35))
		_cross.draw_circle(Vector2.ZERO, 2.5, Color(1, 1, 1, 0.9)))
	_root.add_child(_cross)


func _build_prompt() -> void:
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_bottom = -36
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.hide()
	_root.add_child(_prompt)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(box)
	_label(_prompt_title, Style.serif(600), 30, Style.INK, box)
	_label(_prompt_details, Style.sans(400), 16, Style.MUTED, box)
	_label(_prompt_hint, Style.sans(500), 15, Style.BRASS, box).text = "Press E or click to look closer"
	for l in [_prompt_title, _prompt_details, _prompt_hint]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_card() -> void:
	_card.hide()
	_root.add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_card.add_child(box)

	_label(_card_count, Style.sans(500), 15, Style.BRASS, box)
	_label(_card_title, Style.serif(700), 42, Style.INK, box).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(_card_details, Style.sans(400), 17, Style.MUTED, box).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rule := ColorRect.new()
	rule.color = Style.BRASS
	rule.custom_minimum_size = Vector2(48, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(rule)

	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_card_scroll)
	_label(_card_desc, Style.serif(500), 25, Style.INK, _card_scroll)
	_card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	for spec in [["‹  Prev", prev_pressed], ["Next  ›", next_pressed]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect((spec[1] as Signal).emit)
		buttons.add_child(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(gap)
	var back := Button.new()
	back.text = "Back"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(back_pressed.emit)
	buttons.add_child(back)
	_label(_card_keys, Style.sans(400), 14, Style.MUTED, box).text = "← →  browse    ·    E / Esc  back to walking"


func _layout_card() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x / vp.y >= 1.15:
		var w := clampf(vp.x * 0.32, 340.0, 500.0)
		_card.anchor_left = 1.0
		_card.anchor_right = 1.0
		_card.anchor_top = 0.0
		_card.anchor_bottom = 1.0
		_card.offset_left = -w - 24.0
		_card.offset_right = -24.0
		_card.offset_top = 24.0
		_card.offset_bottom = -24.0
		_space = Vector2(1.0 - (w + 48.0) / vp.x, 1.0)
	else:
		var h := vp.y * 0.42
		_card.anchor_left = 0.0
		_card.anchor_right = 1.0
		_card.anchor_top = 1.0
		_card.anchor_bottom = 1.0
		_card.offset_left = 16.0
		_card.offset_right = -16.0
		_card.offset_top = -h - 16.0
		_card.offset_bottom = -16.0
		_space = Vector2(1.0, 1.0 - (h + 32.0) / vp.y)


func _build_hints() -> void:
	var dark := Color(1, 1, 1, 0.92)
	_label(_hint, Style.sans(400), 16, dark, _root)
	_hint.position = Vector2(24, 20)
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.hide()

	_label(_mouse_hint, Style.sans(500), 18, dark, _root).text = "Click to look around"
	_mouse_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_mouse_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mouse_hint.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mouse_hint.offset_top += 40
	_mouse_hint.offset_bottom += 40
	_mouse_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_mouse_hint.add_theme_constant_override("shadow_offset_y", 1)
	_mouse_hint.hide()


func _build_stick() -> void:
	_stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick.draw.connect(func() -> void:
		if not touch_mode or _card.visible or _intro.visible:
			return
		var origin := _stick_origin
		if not _stick_on:
			origin = Vector2(_stick.size.x * 0.14, _stick.size.y * 0.78)
		_stick.draw_circle(origin, STICK_RADIUS, Color(1, 1, 1, 0.1 if _stick_on else 0.06))
		_stick.draw_arc(origin, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
		var knob := origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS) if _stick_on else origin
		_stick.draw_circle(knob, 26.0, Color(1, 1, 1, 0.45)))
	_root.add_child(_stick)


func _build_intro() -> void:
	_intro.color = Color(0.07, 0.06, 0.055, 0.84)
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_intro)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(centre)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(box)

	var welcome := _label(Label.new(), Style.sans(500), 17, Style.BRASS, box)
	welcome.text = "W E L C O M E   T O   T H E"
	var title := _label(Label.new(), Style.serif(600), 104, Style.PAPER, box)
	title.text = "Wayside Gallery"
	var rule := ColorRect.new()
	rule.color = Style.BRASS
	rule.custom_minimum_size = Vector2(64, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	box.add_child(gap)
	_label(_intro_action, Style.sans(500), 24, Style.PAPER, box).text = "Click anywhere to enter"
	_label(_intro_keys, Style.sans(400), 16, Color(Style.PAPER, 0.6), box).text = _controls_text()
	for l in [welcome, title, _intro_action, _intro_keys]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _controls_text() -> String:
	if touch_mode:
		return "Left thumb: walk    ·    Right thumb: look around    ·    Tap a picture to look closer"
	return "WASD / arrows  walk    ·    Mouse  look    ·    Shift  stroll faster    ·    E or click  look closer"
