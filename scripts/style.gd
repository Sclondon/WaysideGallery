class_name Style
## Shared colours and fonts.

const PAPER := Color(0.97, 0.955, 0.93)
const INK := Color(0.13, 0.11, 0.1)
const MUTED := Color(0.45, 0.41, 0.38)
const BRASS := Color(0.72, 0.52, 0.3)

static var _fonts := {}


## Cormorant Garamond at the given weight (300-700).
static func serif(weight := 500) -> Font:
	return _variation("res://fonts/CormorantGaramond.ttf", weight)


## Jost at the given weight (100-900).
static func sans(weight := 400) -> Font:
	return _variation("res://fonts/Jost.ttf", weight)


static func _variation(path: String, weight: int) -> Font:
	var key := "%s@%d" % [path, weight]
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = load(path)
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[key] = f
	return _fonts[key]
