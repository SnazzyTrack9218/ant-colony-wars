## asset_loader.gd
## Autoload singleton — load all game textures through this script.
## Falls back to colored placeholder rectangles when a file is missing.
## Never crashes on missing assets; always prints a warning instead.
##
## Usage:
##   AssetLoader.get_ant_sprite("worker")    -> Texture2D
##   AssetLoader.get_room_sprite("nursery")  -> Texture2D
##   AssetLoader.get_enemy_sprite("spider")  -> Texture2D
##   AssetLoader.get_tile_sprite("dirt")     -> Texture2D
##   AssetLoader.get_ui_icon("food_icon")    -> Texture2D
##
## To add a new asset: add an entry to data/ASSET_MANIFEST.json.
## To replace a placeholder: drop a correctly named PNG in the right folder.

extends Node

const MANIFEST_PATH: String = "res://data/ASSET_MANIFEST.json"
const PLACEHOLDER_SIZE: Vector2i = Vector2i(32, 32)

## Distinct color per category makes placeholder art easy to identify.
const PLACEHOLDER_COLORS: Dictionary = {
	"ants":    Color(0.80, 0.50, 0.10),  # amber
	"rooms":   Color(0.30, 0.60, 0.90),  # blue
	"tiles":   Color(0.45, 0.35, 0.20),  # brown
	"enemies": Color(0.90, 0.20, 0.20),  # red
	"ui":      Color(0.85, 0.85, 0.85),  # light grey
}

var _manifest: Dictionary = {}
var _texture_cache: Dictionary = {}
var _placeholder_cache: Dictionary = {}


func _ready() -> void:
	_load_manifest()


# ── Public API ────────────────────────────────────────────────────────────────

func get_ant_sprite(asset_name: String) -> Texture2D:
	return _get_texture("ants", asset_name)


func get_room_sprite(asset_name: String) -> Texture2D:
	return _get_texture("rooms", asset_name)


func get_enemy_sprite(asset_name: String) -> Texture2D:
	return _get_texture("enemies", asset_name)


func get_tile_sprite(asset_name: String) -> Texture2D:
	return _get_texture("tiles", asset_name)


func get_ui_icon(asset_name: String) -> Texture2D:
	return _get_texture("ui", asset_name)


## Call this during development to hot-reload changed art without restarting.
func reload_manifest() -> void:
	_texture_cache.clear()
	_placeholder_cache.clear()
	_manifest.clear()
	_load_manifest()
	print("AssetLoader: manifest reloaded.")


# ── Internal ──────────────────────────────────────────────────────────────────

func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("AssetLoader: ASSET_MANIFEST.json not found at '%s'. All textures will use placeholders." % MANIFEST_PATH)
		return

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("AssetLoader: Could not open ASSET_MANIFEST.json (error %d)." % FileAccess.get_open_error())
		return

	var text := file.get_as_text()
	file.close()

	var result = JSON.parse_string(text)
	if result == null:
		push_error("AssetLoader: ASSET_MANIFEST.json contains invalid JSON.")
		return

	_manifest = result
	print("AssetLoader: manifest loaded (%d categories)." % _manifest.size())


func _get_texture(category: String, asset_name: String) -> Texture2D:
	if _manifest.is_empty():
		return _make_placeholder(category)

	var category_map: Dictionary = _manifest.get(category, {})
	if category_map.is_empty():
		push_warning("AssetLoader: Unknown category '%s'." % category)
		return _make_placeholder(category)

	var asset_path: String = category_map.get(asset_name, "")
	if asset_path.is_empty():
		push_warning("AssetLoader: No manifest entry for '%s/%s'." % [category, asset_name])
		return _make_placeholder(category)

	var cache_key: String = category + "/" + asset_name
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]

	if not ResourceLoader.exists(asset_path):
		push_warning("AssetLoader: Missing file '%s' — placeholder used for %s/%s." % [asset_path, category, asset_name])
		return _make_placeholder(category)

	var tex := load(asset_path) as Texture2D
	if tex == null:
		push_warning("AssetLoader: '%s' loaded but is not a Texture2D — placeholder used." % asset_path)
		return _make_placeholder(category)

	_texture_cache[cache_key] = tex
	return tex


func _make_placeholder(category: String) -> ImageTexture:
	if _placeholder_cache.has(category):
		return _placeholder_cache[category]

	var color: Color = PLACEHOLDER_COLORS.get(category, Color.MAGENTA)
	var img := Image.create(PLACEHOLDER_SIZE.x, PLACEHOLDER_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	_placeholder_cache[category] = tex
	return tex
