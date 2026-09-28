class_name Gallery
extends Node3D
## Builds the gallery: a row of rooms joined by doorways, running away from the entrance
## along -Z. Artwork is hung in visiting order (left wall, far wall, right wall, next room)
## and the last piece gets the end wall of the last room to itself.

const ROOM_W := 12.0
const ROOM_D := 11.0
const WALL_H := 4.2
const WALL_T := 0.3
const DOOR_W := 2.4
const DOOR_H := 3.0
const EYE_LINE := 1.5      ## centre height for most pictures
const MAX_ART := Vector2(2.6, 2.4)
const FEATURE_MAX := Vector2(7.0, 2.8)
const SPOT_OUT := 2.1      ## how far from the wall the picture lights hang

const ART_LAYER := 2       ## collision layer the pictures sit on, for aiming at them

var spawn_position := Vector3(0.0, 0.0, -1.8)

var _wall_mat := _material(Color(0.9, 0.88, 0.84), 0.95)
var _ceiling_mat := _material(Color(0.82, 0.8, 0.77), 1.0)
var _trim_mat := _material(Color(0.2, 0.15, 0.11), 0.6)
var _fixture_mat := _material(Color(0.08, 0.08, 0.08), 0.4)
var _plaque_mat := _material(Color(0.95, 0.94, 0.91), 0.8)
var _skylight_mat := _emissive(Color(0.95, 0.92, 0.86), 0.55)
var _floor_mat := ShaderMaterial.new()
var _frame_mats := {
	"black": _material(Color(0.05, 0.05, 0.05), 0.45),
	"walnut": _material(Color(0.24, 0.15, 0.09), 0.5),
	"oak": _material(Color(0.66, 0.5, 0.32), 0.6),
	"gold": _metal(Color(0.76, 0.6, 0.36), 0.4),
	"white": _material(Color(0.93, 0.92, 0.89), 0.7),
}


func build(pieces: Array[ArtPiece]) -> void:
	_floor_mat.shader = load("res://shaders/floor.gdshader")
	var rooms := 1
	while 6 * (rooms - 1) + 5 < pieces.size():
		rooms += 1

	var slots := []
	var feature := {}
	for i in rooms:
		var room_slots := _build_room(i, rooms)
		if i == rooms - 1:
			feature = room_slots.pop_back()
		slots.append_array(room_slots)

	for i in pieces.size():
		var last := i == pieces.size() - 1
		_hang(pieces[i], i, feature if last else slots[i], last)

	if rooms > 1:
		var sign := _label("WAYSIDE GALLERY", Style.serif(600), 150, 0.0026, Color(0.24, 0.2, 0.17))
		sign.position = Vector3(0.0, (DOOR_H + WALL_H) * 0.5 + 0.02, -ROOM_D + WALL_T * 0.5 + 0.01)
		add_child(sign)


## Builds room i and returns its picture slots in visiting order; the last room's
## final slot is its end wall.
func _build_room(i: int, rooms: int) -> Array:
	var last := i == rooms - 1
	var z0 := -i * ROOM_D
	var z1 := z0 - ROOM_D
	var zc := (z0 + z1) * 0.5
	var hx := ROOM_W * 0.5

	_box(Vector3(0.0, -0.1, zc), Vector3(ROOM_W + WALL_T * 2.0, 0.2, ROOM_D), _floor_mat, true)
	_box(Vector3(0.0, WALL_H + 0.1, zc), Vector3(ROOM_W + WALL_T * 2.0, 0.2, ROOM_D), _ceiling_mat, false)
	_box(Vector3(0.0, WALL_H - 0.01, zc), Vector3(4.4, 0.04, 6.0), _skylight_mat, false)
	for s in [-1.0, 1.0]:
		_box(Vector3(s * (hx + WALL_T * 0.5), WALL_H * 0.5, zc), Vector3(WALL_T, WALL_H, ROOM_D), _wall_mat, true)
		_box(Vector3(s * (hx - 0.015), 0.06, zc), Vector3(0.03, 0.12, ROOM_D), _trim_mat, false)
		_bench(Vector3(s * 2.4, 0.0, zc))
	if i == 0:
		_end_wall(WALL_T * 0.5, false, [-1.0])
	if last:
		_end_wall(z1 - WALL_T * 0.5, false, [1.0])
	else:
		_end_wall(z1, true, [1.0, -1.0])

	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, WALL_H - 0.6, zc)
	fill.omni_range = 10.0
	fill.light_energy = 0.55
	fill.light_color = Color(1.0, 0.94, 0.86)
	add_child(fill)

	var q := ROOM_D * 0.25
	var far_face := z1 + (0.0 if last else WALL_T * 0.5)
	var side_room := Vector2(minf(ROOM_D * 0.5 - 2.0, MAX_ART.x), MAX_ART.y)
	var slots := [
		{"pos": Vector3(-hx, 0.0, z0 - q), "normal": Vector3.RIGHT, "max": side_room, "clear": ROOM_W},
		{"pos": Vector3(-hx, 0.0, z1 + q), "normal": Vector3.RIGHT, "max": side_room, "clear": ROOM_W},
	]
	if not last:
		var seg := (ROOM_W - DOOR_W) * 0.5
		for s in [-1.0, 1.0]:
			slots.append({"pos": Vector3(s * (DOOR_W + seg) * 0.5, 0.0, far_face), "normal": Vector3.BACK,
				"max": Vector2(minf(seg - 2.0, MAX_ART.x), MAX_ART.y), "clear": ROOM_D})
	slots.append({"pos": Vector3(hx, 0.0, z1 + q), "normal": Vector3.LEFT, "max": side_room, "clear": ROOM_W})
	slots.append({"pos": Vector3(hx, 0.0, z0 - q), "normal": Vector3.LEFT, "max": side_room, "clear": ROOM_W})
	if last:
		slots.append({"pos": Vector3(0.0, 0.0, far_face), "normal": Vector3.BACK, "max": FEATURE_MAX, "clear": ROOM_D})
	return slots


## A wall across the gallery centred on z, optionally with a doorway. faces lists which
## sides (-1 toward -Z, +1 toward +Z) get a skirting board.
func _end_wall(z: float, door: bool, faces: Array) -> void:
	var spans := [Vector2(-ROOM_W * 0.5, ROOM_W * 0.5)]
	if door:
		spans = [Vector2(-ROOM_W * 0.5, -DOOR_W * 0.5), Vector2(DOOR_W * 0.5, ROOM_W * 0.5)]
		_box(Vector3(0.0, (DOOR_H + WALL_H) * 0.5, z), Vector3(DOOR_W, WALL_H - DOOR_H, WALL_T), _wall_mat, true)
		for s in [-1.0, 1.0]:
			_box(Vector3(s * (DOOR_W * 0.5 + 0.05), DOOR_H * 0.5, z), Vector3(0.14, DOOR_H, WALL_T + 0.04), _trim_mat, false)
		_box(Vector3(0.0, DOOR_H + 0.05, z), Vector3(DOOR_W + 0.38, 0.14, WALL_T + 0.04), _trim_mat, false)
	for span: Vector2 in spans:
		var mid := (span.x + span.y) * 0.5
		var width := span.y - span.x
		_box(Vector3(mid, WALL_H * 0.5, z), Vector3(width, WALL_H, WALL_T), _wall_mat, true)
		for f: float in faces:
			_box(Vector3(mid, 0.06, z + f * (WALL_T * 0.5 + 0.015)), Vector3(width, 0.12, 0.03), _trim_mat, false)


func _bench(at: Vector3) -> void:
	_box(at + Vector3(0.0, 0.43, 0.0), Vector3(0.55, 0.07, 2.2), _frame_mats.walnut, true)
	for s in [-1.0, 1.0]:
		_box(at + Vector3(0.0, 0.2, s * 0.9), Vector3(0.45, 0.4, 0.07), _trim_mat, false)


func _hang(p: ArtPiece, index: int, slot: Dictionary, feature: bool) -> void:
	var limit: Vector2 = slot.max
	var fit := minf(1.0, minf(limit.x / p.width_m, limit.y / p.height_m))
	var size := Vector2(p.width_m, p.height_m) * fit
	var border := 0.0 if p.frame == "none" else clampf(0.03 + 0.02 * maxf(size.x, size.y), 0.04, 0.09)
	var outer := size + Vector2(border, border) * 2.0

	var n: Vector3 = slot.normal
	var centre: Vector3 = slot.pos
	centre.y = maxf(EYE_LINE if not feature else 1.7, outer.y * 0.5 + 0.6)
	var root := Node3D.new()
	root.transform = Transform3D(Basis.looking_at(-n), centre)
	add_child(root)

	var canvas := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	canvas.mesh = quad
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = p.texture
	paint.roughness = 0.7
	paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	canvas.material_override = paint
	canvas.position.z = 0.05
	root.add_child(canvas)

	if p.frame == "none":
		_box(Vector3(0.0, 0.0, 0.024), Vector3(size.x, size.y, 0.048), _material(Color(0.85, 0.84, 0.8), 0.9), false, root)
	else:
		var mat: Material = _frame_mats.get(p.frame, _frame_mats.black)
		var depth := 0.07
		_box(Vector3(0.0, 0.0, 0.02), Vector3(size.x, size.y, 0.04), _trim_mat, false, root)
		for s in [-1.0, 1.0]:
			_box(Vector3(0.0, s * (size.y + border) * 0.5, depth * 0.5), Vector3(outer.x, border, depth), mat, false, root)
			_box(Vector3(s * (size.x + border) * 0.5, 0.0, depth * 0.5), Vector3(border, size.y, depth), mat, false, root)

	# plaque to the right, at the height people read wall text
	var plaque := Node3D.new()
	plaque.position = Vector3(outer.x * 0.5 + 0.45, 1.3 - centre.y, 0.0)
	root.add_child(plaque)
	_box(Vector3(0.0, 0.0, 0.006), Vector3(0.4, 0.19, 0.012), _plaque_mat, false, plaque)
	var title := _label(p.title, Style.serif(700), 44, 0.0007, Style.INK)
	title.position = Vector3(0.0, 0.03, 0.013)
	title.width = 0.36 / 0.0007
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plaque.add_child(title)
	var byline := PackedStringArray()
	for bit in [p.artist, p.year]:
		if not bit.is_empty():
			byline.append(bit)
	var sub := _label(", ".join(byline), Style.sans(400), 32, 0.0007, Style.MUTED)
	sub.position = Vector3(0.0, -0.05, 0.013)
	plaque.add_child(sub)

	# something to aim at
	var body := StaticBody3D.new()
	body.collision_layer = ART_LAYER
	body.collision_mask = 0
	body.set_meta("piece", index)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(outer.x, outer.y, 0.1)
	shape.shape = box
	shape.position.z = 0.05
	body.add_child(shape)
	root.add_child(body)

	_picture_light(centre, n, outer, feature)

	p.index = index
	p.center = centre + n * 0.05
	p.normal = n
	p.outer_size = outer
	p.clearance = slot.clear


func _picture_light(centre: Vector3, n: Vector3, outer: Vector2, feature: bool) -> void:
	var out := SPOT_OUT + (1.0 if feature else 0.0)
	var at := centre + n * out
	at.y = WALL_H - 0.3
	var reach := at.distance_to(centre)
	var spot := SpotLight3D.new()
	add_child(spot)
	spot.look_at_from_position(at, centre, Vector3.UP if absf(n.y) < 0.9 else Vector3.FORWARD)
	spot.spot_range = reach + 2.0
	spot.spot_angle = clampf(rad_to_deg(atan((outer.length() * 0.5 + 0.35) / reach)), 15.0, 60.0)
	spot.spot_angle_attenuation = 0.6
	spot.spot_attenuation = 0.4
	spot.light_energy = 2.2 if feature else 1.8
	spot.light_color = Color(1.0, 0.92, 0.8)

	var can := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.06
	cyl.height = 0.18
	can.mesh = cyl
	can.material_override = _fixture_mat
	can.transform = Transform3D(Basis(Quaternion(Vector3.DOWN, (centre - at).normalized())), at)
	add_child(can)
	_box(Vector3(at.x, WALL_H - 0.12, at.z), Vector3(0.03, 0.24, 0.03), _fixture_mat, false)


func _box(pos: Vector3, size: Vector3, mat: Material, solid: bool, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		inst.add_child(body)
	return inst


func _label(text: String, font: Font, size: int, pixel: float, colour: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = colour
	l.outline_size = 0
	l.double_sided = false
	return l


static func _material(colour: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = roughness
	return m


static func _metal(colour: Color, roughness: float) -> StandardMaterial3D:
	var m := _material(colour, roughness)
	m.metallic = 0.55
	return m


static func _emissive(colour: Color, energy: float) -> StandardMaterial3D:
	var m := _material(colour, 1.0)
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	return m
