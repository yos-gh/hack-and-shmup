extends RefCounted

const Catalog = preload("res://scripts/combat_catalog.gd")
const RunState = preload("res://scripts/run_state.gd")

# Retro resume password: the run as it stood when the current floor began
# (floor, that floor's generator state, the boss met before it, upgrade cards,
# selected sub weapon, deaths and kills). A keyed checksum scrambles the body,
# so one changed character alters the whole password and fails the check.
# Not secure against a determined player; it only stops casual edits.
const VERSION := 1
const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const SALT := "ENDLESS-DESCENT/glyph-wire"
const SCRAMBLE := 0x5EED1E55
const MAX_FLOOR := 99999
const GROUP := 5

# Text for the pause screen, grouped for reading aloud and writing down.
static func encode(run) -> String:
	var body := PackedByteArray()
	body.append((run.floor_previous_boss+1) | (run.sub_weapon << 3) | (VERSION << 5))
	_varint(body,run.floor_number)
	for i in range(8): body.append((run.floor_state >> (8*i)) & 0xFF)
	for kind in range(Catalog.UPGRADES.size()): _varint(body,run.upgrade_counts.get(kind,0))
	_varint(body,run.deaths)
	_varint(body,run.floor_kills)
	var check := _checksum(body)
	var bytes := PackedByteArray([check & 0xFF,(check >> 8) & 0xFF,(check >> 16) & 0xFF])
	bytes.append_array(_scramble(body,check))
	var text := _base32(bytes)
	var groups: Array[String] = []
	for i in range(0,text.length(),GROUP): groups.append(text.substr(i,GROUP))
	return "-".join(groups)

# Returns the run fields, or {"error": reason} for any password that this
# version could not have produced.
static func decode(text: String) -> Dictionary:
	var bytes := _unbase32(text)
	if bytes.size() < 3+1+1+8+Catalog.UPGRADES.size()+2: return {"error":"INVALID PASSWORD"}
	var check := bytes[0] | (bytes[1] << 8) | (bytes[2] << 16)
	var body := _scramble(bytes.slice(3),check)
	if _checksum(body) != check: return {"error":"INVALID PASSWORD"}
	var head := body[0]
	if head >> 5 != VERSION: return {"error":"INVALID PASSWORD"}
	var cursor := [1]
	var result := {}
	result.previous_boss = (head & 0x07)-1
	result.sub_weapon = (head >> 3) & 0x03
	result.floor_number = _read_varint(body,cursor)
	if cursor[0]+8 > body.size(): return {"error":"INVALID PASSWORD"}
	var state := 0
	for i in range(8): state |= body[cursor[0]+i] << (8*i)
	cursor[0] += 8
	result.floor_state = state
	var counts := {}
	for kind in range(Catalog.UPGRADES.size()):
		var count := _read_varint(body,cursor)
		if count > 0: counts[kind] = count
	result.upgrade_counts = counts
	result.deaths = _read_varint(body,cursor)
	result.kills = _read_varint(body,cursor)
	if cursor[0] != body.size() or not legal(result): return {"error":"INVALID PASSWORD"}
	return result

# Rules every real run obeys: one card per cleared floor, card caps and stat
# floors respected, and a previous boss exactly when a boss floor is behind.
static func legal(data: Dictionary) -> bool:
	var floor_number: int = data.floor_number
	if floor_number < 1 or floor_number > MAX_FLOOR: return false
	if data.sub_weapon > 2 or data.previous_boss > 3 or data.deaths < 0 or data.kills < 0: return false
	if (data.previous_boss >= 0) != (floor_number > 5): return false
	var total := 0
	for kind in data.upgrade_counts:
		var count: int = data.upgrade_counts[kind]
		var cap: int = Catalog.UPGRADES[kind].max_stacks
		if count < 0 or (cap > 0 and count > cap): return false
		total += count
	if total != floor_number-1: return false
	var run = RunState.new()
	apply_counts(run,data.upgrade_counts)
	return run.power >= RunState.MIN_POWER-0.00001 and run.move_bonus >= RunState.MIN_MOVE_BONUS

static func apply_counts(run, counts: Dictionary) -> void:
	for kind in counts:
		if counts[kind] > 0: run.upgrade_counts[kind] = counts[kind]
	run.recount_stats()

static func _varint(bytes: PackedByteArray, value: int) -> void:
	while value >= 0x80:
		bytes.append((value & 0x7F) | 0x80)
		value >>= 7
	bytes.append(value)

static func _read_varint(bytes: PackedByteArray, cursor: Array) -> int:
	var value := 0
	var shift := 0
	while cursor[0] < bytes.size() and shift < 35:
		var byte := bytes[cursor[0]]
		cursor[0] += 1
		value |= (byte & 0x7F) << shift
		if byte < 0x80: return value
		shift += 7
	cursor[0] = bytes.size()+1
	return -1

# 24-bit FNV-1a over a fixed salt and the body.
static func _checksum(body: PackedByteArray) -> int:
	var h := 0x811C9DC5
	var salted := SALT.to_utf8_buffer()
	salted.append_array(body)
	for byte in salted: h = ((h ^ byte) * 0x01000193) & 0xFFFFFFFF
	return (h ^ (h >> 24)) & 0xFFFFFF

static func _scramble(body: PackedByteArray, check: int) -> PackedByteArray:
	var out := body.duplicate()
	var x := (check ^ SCRAMBLE) & 0xFFFFFFFF
	if x == 0: x = SCRAMBLE
	for i in range(out.size()):
		x ^= (x << 13) & 0xFFFFFFFF
		x ^= x >> 17
		x ^= (x << 5) & 0xFFFFFFFF
		out[i] ^= x & 0xFF
	return out

static func _base32(bytes: PackedByteArray) -> String:
	var text := ""
	var buffer := 0
	var bits := 0
	for byte in bytes:
		buffer = (buffer << 8) | byte
		bits += 8
		while bits >= 5:
			bits -= 5
			text += ALPHABET[(buffer >> bits) & 0x1F]
		buffer &= (1 << bits)-1
	if bits > 0: text += ALPHABET[(buffer << (5-bits)) & 0x1F]
	return text

# Forgiving input: case, spaces, dashes and the look-alikes O, I and L.
static func _unbase32(text: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	var buffer := 0
	var bits := 0
	for character in text.to_upper().replace("O","0").replace("I","1").replace("L","1"):
		var value := ALPHABET.find(character)
		if value < 0:
			if character in " -_\t\n\r": continue
			return PackedByteArray()
		buffer = (buffer << 5) | value
		bits += 5
		if bits >= 8:
			bits -= 8
			bytes.append((buffer >> bits) & 0xFF)
		buffer &= (1 << bits)-1
	# Encoding pads the final character with zero bits and never adds one more.
	if bits >= 5 or buffer != 0: return PackedByteArray()
	return bytes
