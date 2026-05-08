extends Node

var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _sfx_streams: Dictionary = {}
var _music_stub: AudioStreamWAV
var _placeholder_sfx_enabled: bool = false


func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = _get_audio_bus("SFX")
	add_child(_sfx_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = _get_audio_bus("Music")
	add_child(_music_player)
	_build_placeholder_audio()


func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.play()


func play_event(event_name: String) -> void:
	play_sfx(_sfx_streams.get(event_name, null))


func play_dig_complete() -> void:
	play_event("dig_complete")


func play_food_gathered() -> void:
	play_event("food_gathered")


func play_ant_spawned() -> void:
	play_event("ant_spawned")


func play_queen_damaged() -> void:
	play_event("queen_damaged")


func play_marker_placed() -> void:
	play_event("marker_placed")


func play_music(stream: AudioStream) -> void:
	if stream == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()


func play_music_mode(_mode: String = "peace") -> void:
	play_music(_music_stub)


func stop_music() -> void:
	_music_player.stop()


func _get_audio_bus(bus_name: String) -> String:
	return bus_name if AudioServer.get_bus_index(bus_name) != -1 else "Master"


func _build_placeholder_audio() -> void:
	if not _placeholder_sfx_enabled:
		_sfx_streams = {}
		_music_stub = _make_silence_loop()
		return
	_sfx_streams = {
		"dig_complete": _make_tone_stream(160.0, 0.055, 0.08),
		"food_gathered": _make_tone_stream(520.0, 0.05, 0.07),
		"ant_spawned": _make_tone_stream(360.0, 0.07, 0.06),
		"queen_damaged": _make_tone_stream(90.0, 0.09, 0.10),
		"marker_placed": _make_tone_stream(740.0, 0.035, 0.05),
	}
	_music_stub = _make_silence_loop()


func _make_tone_stream(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var sample_count: int = maxi(1, int(float(mix_rate) * duration))
	var data := PackedByteArray()
	for sample_index in range(sample_count):
		var fade: float = 1.0 - (float(sample_index) / float(sample_count))
		var wave: float = sin(TAU * frequency * float(sample_index) / float(mix_rate))
		var sample_value: int = clampi(int(wave * amplitude * fade * 32767.0), -32768, 32767)
		data.append(sample_value & 0xff)
		data.append((sample_value >> 8) & 0xff)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


func _make_silence_loop() -> AudioStreamWAV:
	var mix_rate: int = 22050
	var sample_count: int = mix_rate
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = data
	return stream
