extends Node

const SAMPLE_RATE := 22050

var _pool: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _cursor := 0
var _cursor3d := 0
var _cache: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	for i in 12:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 8.0
		p3.max_distance = 48.0
		p3.bus = "Master"
		add_child(p3)
		_pool3d.append(p3)


func play(kind: String) -> void:
	if _pool.is_empty():
		return
	var player := _pool[_cursor]
	_cursor = (_cursor + 1) % _pool.size()
	player.stream = _stream(kind)
	player.pitch_scale = randf_range(0.92, 1.08)
	player.play()


func play_at(kind: String, world_pos: Vector3) -> void:
	if _pool3d.is_empty():
		return
	var player := _pool3d[_cursor3d]
	_cursor3d = (_cursor3d + 1) % _pool3d.size()
	player.global_position = world_pos
	player.stream = _stream(kind)
	player.pitch_scale = randf_range(0.9, 1.1)
	player.play()


func _stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var data: PackedByteArray
	match kind:
		"mg":
			data = _noise_burst(0.055, 1800.0, 0.35)
		"shotgun":
			data = _noise_burst(0.22, 900.0, 0.7)
		"rocket":
			data = _boom(0.18)
		"explode":
			data = _boom(0.45)
		"rail":
			data = _zap(0.16, 1400.0, 220.0)
		"jump":
			data = _tone_slide(0.08, 220.0, 340.0, 0.25)
		"hurt":
			data = _noise_burst(0.1, 400.0, 0.45)
		"pickup":
			data = _tone_slide(0.12, 520.0, 880.0, 0.3)
		"pad":
			data = _tone_slide(0.16, 180.0, 520.0, 0.4)
		"teleport":
			data = _zap(0.2, 200.0, 1200.0)
		"death":
			data = _boom(0.35)
		"ui":
			data = _tone_slide(0.06, 440.0, 660.0, 0.2)
		_:
			data = _tone_slide(0.08, 300.0, 300.0, 0.2)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	_cache[kind] = stream
	return stream


func _tone_slide(duration: float, f0: float, f1: float, amp: float) -> PackedByteArray:
	var n := int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var u := float(i) / float(max(n - 1, 1))
		var freq := lerpf(f0, f1, u)
		var env := 1.0 - u
		var s := sin(TAU * freq * t) * amp * env
		_write16(bytes, i, s)
	return bytes


func _zap(duration: float, f0: float, f1: float) -> PackedByteArray:
	var n := int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var u := float(i) / float(max(n - 1, 1))
		var freq := lerpf(f0, f1, u)
		var square := 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
		var env := (1.0 - u) * 0.28
		_write16(bytes, i, square * env)
	return bytes


func _noise_burst(duration: float, lowpass: float, amp: float) -> PackedByteArray:
	var n := int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var y := 0.0
	var a := 1.0 - exp(-lowpass / SAMPLE_RATE)
	for i in n:
		var u := float(i) / float(max(n - 1, 1))
		var env := (1.0 - u) * (1.0 - u)
		y += a * ((randf() * 2.0 - 1.0) - y)
		_write16(bytes, i, y * amp * env)
	return bytes


func _boom(duration: float) -> PackedByteArray:
	var n := int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var y := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var u := float(i) / float(max(n - 1, 1))
		var env := (1.0 - u) * (1.0 - u)
		y = y * 0.92 + (randf() * 2.0 - 1.0) * 0.08
		var s := sin(TAU * lerpf(90.0, 40.0, u) * t) * 0.55 + y * 0.45
		_write16(bytes, i, s * env * 0.7)
	return bytes


func _write16(bytes: PackedByteArray, i: int, sample: float) -> void:
	var v := int(clampf(sample, -1.0, 1.0) * 32767.0)
	bytes[i * 2] = v & 0xFF
	bytes[i * 2 + 1] = (v >> 8) & 0xFF
