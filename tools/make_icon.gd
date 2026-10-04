extends SceneTree

# Rasterizes assets/icon/icon.svg into assets/icon/icon.ico (PNG-compressed entries, 16-256 px) for the
# Windows executable. Run after editing the SVG:
# Godot_console.exe --headless --path . --script res://tools/make_icon.gd
# --preview=<path.png> also writes a 512 px PNG for review.

const SOURCE := "res://assets/icon/icon.svg"
const OUTPUT := "res://assets/icon/icon.ico"
const SIZES := [16, 24, 32, 48, 64, 128, 256]

func _initialize() -> void:
	var svg := FileAccess.get_file_as_string(SOURCE)
	var entries: Array[PackedByteArray] = []
	for size in SIZES:
		var image := Image.new()
		if image.load_svg_from_string(svg, size / 256.0) != OK:
			printerr("Cannot rasterize ", SOURCE)
			quit(1)
			return
		entries.append(image.save_png_to_buffer())
	var ico := PackedByteArray()
	ico.append_array(words([0, 1, SIZES.size()]))
	var offset := 6 + 16 * SIZES.size()
	for i in range(SIZES.size()):
		var edge: int = SIZES[i] % 256
		ico.append_array(PackedByteArray([edge, edge, 0, 0]))
		ico.append_array(words([1, 32]))
		ico.append_array(dwords([entries[i].size(), offset]))
		offset += entries[i].size()
	for entry in entries: ico.append_array(entry)
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_buffer(ico)
	file.close()
	print("Saved ", OUTPUT)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview="):
			var preview := Image.new()
			preview.load_svg_from_string(svg, 2.0)
			preview.save_png(argument.trim_prefix("--preview="))
	quit(0)

func words(values: Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	for value in values: bytes.append_array(PackedByteArray([value & 0xff, (value >> 8) & 0xff]))
	return bytes

func dwords(values: Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	for value in values: bytes.append_array(PackedByteArray([value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, (value >> 24) & 0xff]))
	return bytes
