extends SceneTree
## Paints the placeholder artwork into res://art/ and writes res://art/catalog.json.
##   godot --headless --path . -s scripts/tools/bake_placeholders.gd
##   godot --headless --path . --import
## Once your own art is in, delete the placeholder_*.png files and their catalog entries.

const LONG_SIDE := 640

var n := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()


func _init() -> void:
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	n.frequency = 1.0
	rng.seed = 1234

	var pieces: Array[Dictionary] = [
		{"title": "Wayside Evening", "aspect": 1.5, "paint": _sunset_hills,
			"description": "Three ridgelines settle into the dusk while the sun slips behind the nearest hill."},
		{"title": "Colour Field I", "aspect": 0.75, "paint": func(img: Image) -> void: _color_field(img, Color(0.45, 0.12, 0.1), [
				[Rect2(0.1, 0.07, 0.8, 0.45), Color(0.86, 0.38, 0.14)],
				[Rect2(0.1, 0.58, 0.8, 0.35), Color(0.28, 0.05, 0.07)]]),
			"description": "Two soft-edged blocks of colour hover over a deep red ground."},
		{"title": "Composition with Red", "aspect": 1.0, "paint": func(img: Image) -> void: _grid_composition(img,
				[0.24, 0.71, 0.9], [0.3, 0.62, 0.84],
				{0: Color(0.8, 0.14, 0.12), 32: Color(0.12, 0.24, 0.55), 23: Color(0.95, 0.78, 0.18), 13: Color(0.12, 0.11, 0.1)}),
			"description": "Black lines divide the square into a rhythm of white, with a single loud field of red."},
		{"title": "Tidewater", "aspect": 1.78, "paint": _seascape,
			"description": "Late-morning light over open water, the swell breaking into white along the troughs."},
		{"title": "Nocturne", "aspect": 0.8, "paint": _nocturne,
			"description": "A bare tree keeps watch on the hill under a full moon and a sky full of stars."},
		{"title": "Orbits", "aspect": 1.0, "paint": _orbits,
			"description": "Overlapping rings of colour, each one pulling at its neighbours."},
		{"title": "Meadow in Points", "aspect": 1.5, "paint": _meadow,
			"description": "A summer field built entirely from small dabs of colour that only resolve from a distance."},
		{"title": "Colour Field II", "aspect": 1.33, "paint": func(img: Image) -> void: _color_field(img, Color(0.1, 0.17, 0.26), [
				[Rect2(0.08, 0.1, 0.84, 0.42), Color(0.2, 0.5, 0.55)],
				[Rect2(0.08, 0.6, 0.84, 0.3), Color(0.86, 0.74, 0.45)]]),
			"description": "Teal over ochre on a midnight ground: a quieter companion to Colour Field I."},
		{"title": "Birch Row", "aspect": 0.667, "paint": _birches,
			"description": "White trunks stand in a line against the gold of an autumn wood."},
		{"title": "Current", "aspect": 1.0, "paint": _op_waves,
			"description": "Parallel lines bend just enough to make the surface seem to move."},
		{"title": "Gesture", "aspect": 1.5, "paint": _gesture,
			"description": "Fast, loaded brushstrokes laid down in a single sitting."},
		{"title": "Harbour Lights", "aspect": 1.78, "paint": _harbour,
			"description": "A waterfront at night, its lit windows doubled and broken up in the black water."},
		{"title": "Three Pears", "aspect": 1.33, "paint": _pears,
			"description": "A still life in the old manner: fruit, a table edge, and a single window of light."},
		{"title": "First Snow", "aspect": 0.75, "paint": _snowfall,
			"description": "The pines on the far hill disappear one by one as the snow thickens."},
		{"title": "Composition in Blue", "aspect": 1.0, "paint": func(img: Image) -> void: _grid_composition(img,
				[0.18, 0.55, 0.8], [0.22, 0.5, 0.77],
				{11: Color(0.16, 0.3, 0.6), 2: Color(0.62, 0.64, 0.66), 33: Color(0.93, 0.8, 0.3), 30: Color(0.1, 0.16, 0.36)}),
			"description": "The grid again, this time cooled down into blues and a grey."},
		{"title": "The Wayside", "aspect": 2.0, "width_cm": 220, "paint": _wayside,
			"description": "The road runs straight to the mesas. Someone put up a sign, but nobody remembers what it said."},
	]

	var entries := []
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		var file := "placeholder_%02d.png" % (i + 1)
		var img := _canvas(p.aspect)
		(p.paint as Callable).call(img)
		_finish(img)
		img.save_png(ProjectSettings.globalize_path("res://art/" + file))
		var entry := {"file": file, "title": p.title, "year": "2026", "medium": "Placeholder (procedural)",
			"description": p.description}
		if p.has("width_cm"):
			entry["width_cm"] = p.width_cm
		entries.append(entry)
		print("painted ", file, "  ", p.title)

	var f := FileAccess.open("res://art/catalog.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"artist": "", "pieces": entries}, "  ", false) + "\n")
	f.close()
	quit()


# --- painting helpers --------------------------------------------------------

func _canvas(aspect: float) -> Image:
	var w := LONG_SIDE if aspect >= 1.0 else roundi(LONG_SIDE * aspect)
	var h := roundi(LONG_SIDE / aspect) if aspect >= 1.0 else LONG_SIDE
	return Image.create_empty(w, h, false, Image.FORMAT_RGB8)


## Fills every pixel with f(u, v) -> Color, u and v in 0..1.
func _shade(img: Image, f: Callable) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		var v := (y + 0.5) / h
		for x in w:
			img.set_pixel(x, y, f.call((x + 0.5) / w, v))


## Canvas weave and a little paint grain over the whole picture.
func _finish(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var k := 1.0 + 0.03 * n.get_noise_2d(x * 0.4, y * 0.4) + 0.018 * sin(x * 2.2) * sin(y * 2.2)
			var c := img.get_pixel(x, y) * k
			c.a = 1.0
			img.set_pixel(x, y, c)


func _blend(img: Image, x: int, y: int, c: Color, a: float) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height() or a <= 0.0:
		return
	var under := img.get_pixel(x, y)
	img.set_pixel(x, y, under.lerp(Color(c, 1.0), clampf(a, 0.0, 1.0)))


func _disc(img: Image, center: Vector2, r: float, c: Color, a := 1.0) -> void:
	for y in range(floori(center.y - r - 1.0), ceili(center.y + r + 1.0)):
		for x in range(floori(center.x - r - 1.0), ceili(center.x + r + 1.0)):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			_blend(img, x, y, c, a * clampf(r - d + 0.5, 0.0, 1.0))


## A brushstroke segment: a capsule with slightly uneven (bristly) coverage.
func _stroke(img: Image, from: Vector2, to: Vector2, r: float, c: Color, a := 1.0) -> void:
	var lo := from.min(to) - Vector2(r + 1.0, r + 1.0)
	var hi := from.max(to) + Vector2(r + 1.0, r + 1.0)
	var seg := to - from
	var len2 := maxf(seg.length_squared(), 0.0001)
	for y in range(floori(lo.y), ceili(hi.y)):
		for x in range(floori(lo.x), ceili(hi.x)):
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - from).dot(seg) / len2, 0.0, 1.0)
			var d := p.distance_to(from + seg * t)
			var cover := clampf(r - d + 0.5, 0.0, 1.0)
			if cover > 0.0:
				var bristle := 0.82 + 0.18 * n.get_noise_2d(x * 0.9 + y * 0.3, y * 0.9 - x * 0.3)
				_blend(img, x, y, c, a * cover * bristle)


func _vgrad(stops: Array, v: float) -> Color:
	if v <= stops[0][0]:
		return stops[0][1]
	for i in range(1, stops.size()):
		if v <= stops[i][0]:
			var t: float = (v - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0])
			return (stops[i - 1][1] as Color).lerp(stops[i][1], t)
	return stops[-1][1]


func _hash(a: float, b: float) -> float:
	return fposmod(sin(a * 127.1 + b * 311.7) * 43758.5453, 1.0)


func _smin(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


# --- the paintings ------------------------------------------------------------

func _sunset_hills(img: Image) -> void:
	var aspect := float(img.get_width()) / img.get_height()
	var sun := Vector2(0.68, 0.5)
	var ridges := [
		[0.52, 0.10, 2.0, Color(0.62, 0.4, 0.46)],
		[0.63, 0.08, 3.0, Color(0.4, 0.25, 0.33)],
		[0.75, 0.07, 4.0, Color(0.19, 0.12, 0.18)],
	]
	var f := func(u: float, v: float) -> Color:
		var c := _vgrad([[0.0, Color(0.2, 0.16, 0.36)], [0.33, Color(0.7, 0.36, 0.42)], [0.55, Color(0.99, 0.72, 0.42)]], v)
		var d := Vector2((u - sun.x) * aspect, v - sun.y).length()
		c += Color(0.35, 0.18, 0.05) * exp(-d * 7.0)
		c = c.lerp(Color(1.0, 0.94, 0.74), smoothstep(0.062, 0.056, d))
		for k in ridges.size():
			var r: Array = ridges[k]
			var top: float = r[0] + r[1] * n.get_noise_2d(u * r[2], k * 7.3)
			if v > top:
				c = (r[3] as Color).lerp(Color(0.06, 0.04, 0.07), clampf((v - top) * 1.2, 0.0, 0.6))
		return c
	_shade(img, f)


func _color_field(img: Image, ground: Color, bands: Array) -> void:
	var f := func(u: float, v: float) -> Color:
		var c := ground
		for b in bands:
			var r: Rect2 = b[0]
			var wobble := 0.012 * n.get_noise_2d(u * 9.0, v * 9.0)
			var edge := minf(minf(u - r.position.x, r.end.x - u), minf(v - r.position.y, r.end.y - v)) + wobble
			var tone: Color = (b[1] as Color) * (1.0 + 0.09 * n.get_noise_2d(u * 3.0 + 5.0, v * 3.0))
			c = c.lerp(tone, smoothstep(-0.012, 0.02, edge) * 0.95)
		return c * (1.0 + 0.05 * n.get_noise_2d(u * 2.0, v * 2.0 + 9.0))
	_shade(img, f)


## Mondrian-style grid. fills maps column * 10 + row -> colour; other cells are off-white.
func _grid_composition(img: Image, xs: Array, ys: Array, fills: Dictionary) -> void:
	var f := func(u: float, v: float) -> Color:
		var col := 0
		var row := 0
		for x: float in xs:
			if absf(u - x) < 0.013:
				return Color(0.1, 0.09, 0.09)
			if u > x:
				col += 1
		for y: float in ys:
			if absf(v - y) < 0.013:
				return Color(0.1, 0.09, 0.09)
			if v > y:
				row += 1
		var c: Color = fills.get(col * 10 + row, Color(0.94, 0.92, 0.86))
		return c * (1.0 + 0.04 * n.get_noise_2d(u * 6.0, v * 6.0))
	_shade(img, f)


func _seascape(img: Image) -> void:
	var horizon := 0.45
	var f := func(u: float, v: float) -> Color:
		if v < horizon:
			var c := _vgrad([[0.0, Color(0.42, 0.6, 0.8)], [horizon, Color(0.93, 0.9, 0.82)]], v)
			var cloud := n.get_noise_2d(u * 2.5, v * 7.0)
			return c.lerp(Color(0.98, 0.97, 0.94), smoothstep(0.05, 0.4, cloud) * (1.0 - v / horizon * 0.6))
		var depth := (v - horizon) / (1.0 - horizon)
		var c := Color(0.36, 0.56, 0.62).lerp(Color(0.08, 0.26, 0.36), depth)
		var wave := n.get_noise_2d(u * 2.5 / (depth + 0.12), log(depth + 0.02) * 14.0)
		c = c.lerp(Color(0.92, 0.95, 0.95), smoothstep(0.3, 0.5, wave))
		c += Color(0.3, 0.28, 0.2) * exp(-absf(u - 0.3) * 12.0) * (1.0 - depth) * 0.6
		return c
	_shade(img, f)


func _nocturne(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var moon := Vector2(0.72 * w, 0.2 * h)
	var f := func(u: float, v: float) -> Color:
		var c := _vgrad([[0.0, Color(0.03, 0.04, 0.12)], [0.78, Color(0.13, 0.15, 0.32)]], v)
		c += Color(0.25, 0.25, 0.3) * exp(-Vector2(u * w, v * h).distance_to(moon) / (0.12 * w))
		if v > 0.8 + 0.04 * n.get_noise_2d(u * 2.0, 3.0):
			c = Color(0.03, 0.035, 0.05)
		return c
	_shade(img, f)
	for i in 180:
		var p := Vector2(rng.randf() * w, rng.randf() * h * 0.75)
		_disc(img, p, rng.randf_range(0.5, 1.5), Color(0.95, 0.95, 1.0), rng.randf_range(0.4, 1.0))
	_disc(img, moon, 0.07 * w, Color(0.97, 0.94, 0.82))
	for i in 6:
		var off := Vector2(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.04, 0.04)) * w
		_disc(img, moon + off, rng.randf_range(0.006, 0.014) * w, Color(0.85, 0.82, 0.72), 0.6)
	_branch(img, Vector2(0.27 * w, 0.84 * h), -PI / 2.0, 0.2 * h, 6.0, 6)


func _branch(img: Image, from: Vector2, angle: float, length: float, r: float, depth: int) -> void:
	var to := from + Vector2.from_angle(angle) * length
	_stroke(img, from, to, r, Color(0.02, 0.02, 0.03))
	if depth == 0:
		return
	for side in [-1.0, 1.0]:
		var bend: float = side * rng.randf_range(0.3, 0.6)
		_branch(img, to, angle + bend, length * rng.randf_range(0.6, 0.78), maxf(r * 0.68, 0.7), depth - 1)


func _orbits(img: Image) -> void:
	var circles := [[Vector2(0.3, 0.35), 0.28], [Vector2(0.7, 0.62), 0.34], [Vector2(0.64, 0.2), 0.14], [Vector2(0.22, 0.78), 0.18]]
	var pal := [Color(0.8, 0.25, 0.2), Color(0.93, 0.7, 0.25), Color(0.18, 0.3, 0.6), Color(0.25, 0.55, 0.5),
		Color(0.95, 0.9, 0.8), Color(0.12, 0.1, 0.1)]
	var f := func(u: float, v: float) -> Color:
		var grain := 1.0 + 0.05 * n.get_noise_2d(u * 5.0, v * 5.0)
		for k in circles.size():
			var d := Vector2(u, v).distance_to(circles[k][0])
			var radius: float = circles[k][1]
			if d < radius:
				return (pal[(int(d / radius * 5.0) + k * 2) % pal.size()] as Color) * grain
		return Color(0.9, 0.85, 0.74) * grain
	_shade(img, f)


func _meadow_colour(u: float, v: float) -> Color:
	if v < 0.44 + 0.02 * n.get_noise_2d(u * 6.0, 1.0):
		var sky := _vgrad([[0.0, Color(0.5, 0.66, 0.9)], [0.44, Color(0.86, 0.9, 0.95)]], v)
		return sky.lerp(Color.WHITE, smoothstep(0.1, 0.4, n.get_noise_2d(u * 3.0, v * 8.0)))
	if v < 0.49 + 0.03 * n.get_noise_2d(u * 9.0, 4.0):
		return Color(0.18, 0.32, 0.18)
	var c := Color(0.52, 0.66, 0.3).lerp(Color(0.28, 0.45, 0.16), (v - 0.45) / 0.55)
	var flower := n.get_noise_2d(u * 30.0, v * 30.0)
	if flower > 0.35:
		c = Color(0.85, 0.22, 0.2) if n.get_noise_2d(u * 7.0, v * 7.0 + 20.0) > 0.0 else Color(0.95, 0.85, 0.3)
	return c


func _meadow(img: Image) -> void:
	_shade(img, func(u: float, v: float) -> Color: return _meadow_colour(u, v).lerp(Color(0.9, 0.87, 0.8), 0.45))
	var w := img.get_width()
	var h := img.get_height()
	for i in 14000:
		var p := Vector2(rng.randf() * w, rng.randf() * h)
		var c := _meadow_colour(p.x / w, p.y / h)
		c = Color(c.r + rng.randf_range(-0.08, 0.08), c.g + rng.randf_range(-0.08, 0.08), c.b + rng.randf_range(-0.08, 0.08))
		_disc(img, p, rng.randf_range(2.0, 3.2), c, 0.95)


func _birches(img: Image) -> void:
	var trunks := []
	for i in 11:
		trunks.append([rng.randf_range(0.03, 0.97), rng.randf_range(0.015, 0.065)])
	trunks.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	var f := func(u: float, v: float) -> Color:
		var c := _vgrad([[0.0, Color(0.96, 0.78, 0.38)], [0.78, Color(0.78, 0.44, 0.17)]], v)
		c = c.lerp(Color(0.9, 0.35, 0.1), smoothstep(0.25, 0.5, n.get_noise_2d(u * 12.0, v * 12.0)) * 0.6)
		if v > 0.83 + 0.02 * n.get_noise_2d(u * 5.0, 2.0):
			c = Color(0.42, 0.28, 0.14) * (1.0 + 0.15 * n.get_noise_2d(u * 20.0, v * 20.0))
		for t: Array in trunks:
			var half: float = t[1] * 0.5
			var s: float = (u - t[0]) / half
			if absf(s) < 1.0 and v < 0.84 + t[1] * 1.6:
				c = Color(0.94, 0.92, 0.87) * (1.0 - 0.35 * s * s)
				if n.get_noise_2d(t[0] * 40.0 + s * 0.6, v * 28.0) > 0.35:
					c = Color(0.16, 0.14, 0.12)
		return c
	_shade(img, f)


func _op_waves(img: Image) -> void:
	var f := func(u: float, v: float) -> Color:
		var s := sin((v + 0.05 * sin(u * 10.0 + v * 3.0) * (0.4 + u)) * 70.0)
		return Color(0.11, 0.1, 0.1).lerp(Color(0.93, 0.9, 0.84), smoothstep(-0.3, 0.3, s))
	_shade(img, f)


func _gesture(img: Image) -> void:
	_shade(img, func(u: float, v: float) -> Color: return Color(0.92, 0.88, 0.8) * (1.0 + 0.04 * n.get_noise_2d(u * 4.0, v * 4.0)))
	var w := img.get_width()
	var h := img.get_height()
	var pal := [Color(0.1, 0.09, 0.09), Color(0.75, 0.18, 0.12), Color(0.16, 0.25, 0.55), Color(0.85, 0.62, 0.2)]
	for s in 16:
		var p0 := Vector2(rng.randf() * w, rng.randf() * h)
		var p2 := p0 + Vector2(rng.randf_range(-0.5, 0.5) * w, rng.randf_range(-0.4, 0.4) * h)
		var p1 := (p0 + p2) * 0.5 + Vector2(rng.randf_range(-0.2, 0.2) * w, rng.randf_range(-0.2, 0.2) * h)
		var r := rng.randf_range(5.0, 20.0)
		var c: Color = pal[rng.randi() % pal.size()]
		var prev := p0
		for i in range(1, 25):
			var t := i / 24.0
			var q := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
			_stroke(img, prev, q, r * (0.35 + 0.65 * sin(t * PI)), c, 0.9)
			prev = q


func _harbour_scene(u: float, v: float, horizon: float) -> Color:
	var c := _vgrad([[0.0, Color(0.04, 0.04, 0.11)], [horizon, Color(0.22, 0.13, 0.22)]], v)
	var block := floorf(u * 28.0)
	var top := horizon - 0.05 - 0.17 * _hash(block, 1.0)
	if v > top:
		c = Color(0.06, 0.05, 0.08)
		if fposmod(u * 112.0, 1.0) < 0.55 and fposmod(v * 90.0, 1.0) < 0.5 and _hash(block * 4.0 + floorf(u * 112.0), floorf(v * 90.0)) > 0.72:
			c = Color(0.97, 0.8, 0.45)
	return c


func _harbour(img: Image) -> void:
	var horizon := 0.6
	var f := func(u: float, v: float) -> Color:
		if v < horizon:
			return _harbour_scene(u, v, horizon)
		var ripple := n.get_noise_2d(u * 4.0, v * 70.0)
		var mirrored := _harbour_scene(u + 0.012 * ripple, 2.0 * horizon - v - 0.004, horizon)
		return Color(0.03, 0.04, 0.08).lerp(mirrored, 0.55 - (v - horizon) * 0.6)
	_shade(img, f)


func _pears(img: Image) -> void:
	var aspect := float(img.get_width()) / img.get_height()
	var pears := [[Vector2(0.42, 0.62), 0.12], [Vector2(0.72, 0.66), 0.14], [Vector2(1.0, 0.63), 0.1]]
	var light := Vector3(-0.5, -0.6, 0.62).normalized()
	var f := func(u: float, v: float) -> Color:
		var q := Vector2(u * aspect, v)
		var c := Color(0.3, 0.3, 0.2).lerp(Color(0.1, 0.1, 0.07), clampf(q.distance_to(Vector2(0.3, 0.2)), 0.0, 1.0))
		if v > 0.7:
			c = Color(0.42, 0.26, 0.14) * (1.0 + 0.12 * n.get_noise_2d(u * 2.0, v * 40.0))
			if v < 0.715:
				c *= 1.3
		for p: Array in pears:
			var base: Vector2 = p[0]
			var r: float = p[1]
			var shadow := Vector2((q.x - base.x - r * 0.6) / (r * 1.4), (v - base.y - r * 0.9) / (r * 0.25)).length()
			if v > 0.7 and shadow < 1.0:
				c *= 0.55 + 0.45 * shadow
		for p: Array in pears:
			var base: Vector2 = p[0]
			var r: float = p[1]
			var sd := _pear_sdf(q, base, r)
			if sd < 0.0:
				var e := 0.002
				var grad := Vector2(_pear_sdf(q + Vector2(e, 0.0), base, r) - sd, _pear_sdf(q + Vector2(0.0, e), base, r) - sd).normalized()
				var bulge := sqrt(clampf(-sd / (r * 0.9), 0.0, 1.0))
				var normal := Vector3(grad.x, grad.y, 0.0).lerp(Vector3.BACK, bulge).normalized()
				var skin := Color(0.8, 0.78, 0.26).lerp(Color(0.9, 0.48, 0.2), smoothstep(0.0, 0.6, n.get_noise_2d(q.x * 5.0, q.y * 5.0)) * 0.7)
				c = skin * (0.3 + 0.9 * maxf(normal.dot(-light), 0.0))
				c += Color(0.3, 0.3, 0.25) * pow(maxf(normal.dot((-light + Vector3.BACK).normalized()), 0.0), 30.0)
		return c
	_shade(img, f)
	for p: Array in pears:
		var base: Vector2 = p[0]
		var r: float = p[1]
		var stem := (base + Vector2(r * 0.15, -r * 1.55)) * Vector2(img.get_width() / aspect, img.get_height())
		_stroke(img, stem + Vector2(0.0, 0.2 * r * img.get_height()), stem + Vector2(5.0, -0.25 * r * img.get_height()), 2.5, Color(0.25, 0.16, 0.08))


func _pear_sdf(q: Vector2, base: Vector2, r: float) -> float:
	var top := base + Vector2(r * 0.15, -r * 1.05)
	return _smin(q.distance_to(base) - r, q.distance_to(top) - r * 0.58, r * 0.5)


func _triangle(img: Image, apex: Vector2, base_w: float, height: float, c: Color) -> void:
	for y in range(floori(apex.y), ceili(apex.y + height)):
		var half := base_w * 0.5 * (y + 0.5 - apex.y) / height
		for x in range(floori(apex.x - half - 1.0), ceili(apex.x + half + 1.0)):
			_blend(img, x, y, c, clampf(half - absf(x + 0.5 - apex.x) + 0.5, 0.0, 1.0))


func _snowfall(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var hill := func(u: float, k: int) -> float: return [0.55, 0.68, 0.8][k] + 0.05 * n.get_noise_2d(u * 2.5, k * 9.0)
	var f := func(u: float, v: float) -> Color:
		var c := _vgrad([[0.0, Color(0.55, 0.62, 0.72)], [0.6, Color(0.83, 0.85, 0.87)]], v)
		var tones := [Color(0.76, 0.8, 0.87), Color(0.86, 0.89, 0.93), Color(0.96, 0.97, 0.98)]
		for k in 3:
			if v > hill.call(u, k):
				c = tones[k]
		return c
	_shade(img, f)
	for i in 40:
		var u := rng.randf()
		var k := 0 if i < 26 else 1
		var ground: float = hill.call(u, k) * h + 6.0
		var tall := rng.randf_range(0.05, 0.1) * h * (0.7 if k == 0 else 1.3)
		var shade := Color(0.3, 0.38, 0.38) if k == 0 else Color(0.12, 0.2, 0.18)
		_triangle(img, Vector2(u * w, ground - tall), tall * 0.55, tall, shade)
	for i in 700:
		_disc(img, Vector2(rng.randf() * w, rng.randf() * h), rng.randf_range(0.8, 2.6), Color.WHITE, rng.randf_range(0.5, 0.95))


func _wayside(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var aspect := float(w) / h
	var horizon := 0.55
	var f := func(u: float, v: float) -> Color:
		if v < horizon:
			var c := _vgrad([[0.0, Color(0.3, 0.5, 0.78)], [horizon, Color(0.97, 0.78, 0.55)]], v)
			c += Color(0.3, 0.2, 0.05) * exp(-Vector2((u - 0.8) * aspect, v - 0.42).length() * 5.0)
			var mesa := minf(maxf(n.get_noise_2d(u * 3.0, 11.0), 0.0) * 0.45, 0.075)
			if v > horizon - mesa:
				c = Color(0.66, 0.42, 0.36).lerp(Color(0.9, 0.66, 0.5), 0.35)
			return c
		var t := (v - horizon) / (1.0 - horizon)
		var c := Color(0.82, 0.62, 0.36).lerp(Color(0.6, 0.4, 0.22), t)
		if n.get_noise_2d(u * 30.0 / (t + 0.1), v * 40.0 / (t + 0.1)) > 0.45:
			c = Color(0.38, 0.4, 0.22)
		var off := absf(u - 0.5) * aspect
		var half := 0.008 + 0.62 * t
		if off < half:
			c = Color(0.26, 0.25, 0.27) * (1.0 + 0.1 * n.get_noise_2d(u * 60.0, v * 60.0))
			var z := 1.0 / (t + 0.04)
			if off < 0.003 + 0.012 * t and fposmod(z, 1.6) < 0.8:
				c = Color(0.95, 0.78, 0.25)
			if absf(off - half * 0.93) < 0.002 + 0.01 * t:
				c = Color(0.9, 0.88, 0.82)
		return c
	_shade(img, f)
	# telephone poles receding along the right shoulder
	for i in 7:
		var t := 1.0 / (1.0 + i * 1.3)
		var base := Vector2(0.5 * w + (0.02 + 0.85 * t) * h, (horizon + (1.0 - horizon) * t * 0.92) * h)
		var tall := 0.42 * h * t
		_stroke(img, base, base - Vector2(0.0, tall), maxf(3.0 * t, 0.6), Color(0.2, 0.14, 0.1))
		_stroke(img, base - Vector2(tall * 0.14, tall * 0.9), base - Vector2(-tall * 0.14, tall * 0.9), maxf(1.6 * t, 0.5), Color(0.2, 0.14, 0.1))
	# the roadside sign
	var post := Vector2(0.2 * w, 0.93 * h)
	_stroke(img, post, post - Vector2(0.0, 0.3 * h), 3.0, Color(0.3, 0.3, 0.3))
	for y in range(int(0.53 * h), int(0.66 * h)):
		for x in range(int(0.14 * w), int(0.26 * w)):
			var edge := mini(mini(x - int(0.14 * w), int(0.26 * w) - x), mini(y - int(0.53 * h), int(0.66 * h) - y))
			_blend(img, x, y, Color(0.92, 0.9, 0.84) if edge < 4 else Color(0.17, 0.36, 0.26), 1.0)
