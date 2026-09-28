class_name ArtCatalog
## Finds the artwork in res://art/ and reads its details from res://art/catalog.json.
## Any image in the folder is hung, in catalog order first, then by file name.

const ART_DIR := "res://art/"
const CATALOG_PATH := "res://art/catalog.json"
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "bmp", "tga", "svg"]
const FRAMES := ["black", "walnut", "oak", "gold", "white"]
const DEFAULT_LONG_SIDE_M := 1.3  ## when the catalog gives no real-world size


static func load_pieces() -> Array[ArtPiece]:
	var catalog := _read_catalog()
	var files := _image_files()
	var entries := {}
	var order: Array[String] = []
	for entry: Variant in catalog.get("pieces", []):
		if entry is Dictionary and entry.get("file", "") in files and not entries.has(entry.file):
			entries[entry.file] = entry
			order.append(entry.file)
	for file in files:
		if not entries.has(file):
			entries[file] = {}
			order.append(file)

	var pieces: Array[ArtPiece] = []
	for file in order:
		var texture := load(ART_DIR + file) as Texture2D
		if texture == null:
			push_warning("Wayside Gallery: couldn't load art/%s" % file)
			continue
		var e: Dictionary = entries[file]
		var p := ArtPiece.new()
		p.file = file
		p.texture = texture
		p.title = _text(e.get("title", file.get_basename().replace("_", " ").replace("-", " ").capitalize()))
		p.artist = _text(e.get("artist", catalog.get("artist", "")))
		p.year = _text(e.get("year", ""))
		p.medium = _text(e.get("medium", ""))
		p.description = _text(e.get("description", ""))
		p.frame = _text(e.get("frame", FRAMES[file.hash() % FRAMES.size()])).to_lower()
		_set_size(p, e)
		pieces.append(p)
	return pieces


static func _set_size(p: ArtPiece, e: Dictionary) -> void:
	var aspect := float(p.texture.get_width()) / p.texture.get_height()
	if e.has("width_cm") and e.has("height_cm"):
		p.width_m = float(e.width_cm) / 100.0
		p.height_m = float(e.height_cm) / 100.0
	elif e.has("width_cm"):
		p.width_m = float(e.width_cm) / 100.0
		p.height_m = p.width_m / aspect
	elif e.has("height_cm"):
		p.height_m = float(e.height_cm) / 100.0
		p.width_m = p.height_m * aspect
	elif aspect >= 1.0:
		p.width_m = DEFAULT_LONG_SIDE_M
		p.height_m = DEFAULT_LONG_SIDE_M / aspect
	else:
		p.height_m = DEFAULT_LONG_SIDE_M
		p.width_m = DEFAULT_LONG_SIDE_M * aspect


static func _read_catalog() -> Dictionary:
	if not FileAccess.file_exists(CATALOG_PATH):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if data is Dictionary:
		return data
	push_warning("Wayside Gallery: art/catalog.json isn't valid JSON, ignoring it")
	return {}


static func _image_files() -> Array[String]:
	var files: Array[String] = []
	for name in ResourceLoader.list_directory(ART_DIR):
		if name.get_extension().to_lower() in IMAGE_EXTENSIONS:
			files.append(name)
	files.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return files


## JSON numbers arrive as floats; show 2024 rather than 2024.0.
static func _text(value: Variant) -> String:
	if value is float and value == floorf(value):
		return str(int(value))
	return str(value).strip_edges()
