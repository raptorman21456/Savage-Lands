extends RefCounted
class_name Sfx

# Every clip is synthesized at runtime from simple waveforms (sine/square/
# noise) instead of shipping audio assets -- same "procedurally generated,
# no external files" approach gen_sprites.gd takes for the pixel art.

const MIX_RATE := 22050

static func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v: float = clampf(samples[i], -1.0, 1.0)
		data.encode_s16(i * 2, int(round(v * 32767.0)))
	stream.data = data
	return stream

# A single tone (sine/square/noise), with a short linear fade-in/out so
# clips never click at their start/end regardless of waveform or duration.
static func _tone(freq: float, duration: float, wave: String = "sine", volume: float = 0.5) -> PackedFloat32Array:
	var n := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var fade_len := mini(n, int(0.01 * MIX_RATE))
	for i in n:
		var t := float(i) / MIX_RATE
		var phase := t * freq
		var v := 0.0
		match wave:
			"square":
				v = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"noise":
				v = randf_range(-1.0, 1.0)
			_:
				v = sin(phase * TAU)
		var envelope := 1.0
		if i < fade_len:
			envelope = float(i) / float(fade_len)
		elif i > n - fade_len:
			envelope = float(n - i) / float(fade_len)
		samples[i] = v * volume * envelope
	return samples

static func _concat(parts: Array) -> PackedFloat32Array:
	var total := PackedFloat32Array()
	for p in parts:
		total.append_array(p)
	return total

static func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var v := 0.0
		for p in parts:
			if i < p.size():
				v += p[i]
		samples[i] = clampf(v, -1.0, 1.0)
	return samples

static func make_hit() -> AudioStreamWAV:
	var thump := _tone(90.0, 0.09, "square", 0.45)
	var crack := _tone(0.0, 0.05, "noise", 0.25)
	return _make_wav(_mix([thump, crack]))

static func make_death() -> AudioStreamWAV:
	# A falling pitch sweep -- needs a continuously-changing frequency, which
	# the fixed-freq _tone() helper can't do, so this one builds its samples
	# directly instead.
	var duration := 0.35
	var n := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var freq: float = lerpf(420.0, 90.0, t)
		phase += freq / MIX_RATE
		samples[i] = sin(phase * TAU) * 0.5 * (1.0 - t)
	return _make_wav(samples)

static func make_coin() -> AudioStreamWAV:
	return _make_wav(_concat([_tone(880.0, 0.05, "square", 0.3), _tone(1318.0, 0.08, "square", 0.3)]))

static func make_item() -> AudioStreamWAV:
	return _make_wav(_tone(660.0, 0.12, "sine", 0.4))

static func make_shard() -> AudioStreamWAV:
	return _make_wav(_concat([
		_tone(1046.0, 0.05, "square", 0.28),
		_tone(1568.0, 0.05, "square", 0.28),
		_tone(2093.0, 0.08, "square", 0.28),
	]))

static func make_level_up() -> AudioStreamWAV:
	return _make_wav(_concat([
		_tone(523.0, 0.09, "square", 0.4),
		_tone(659.0, 0.09, "square", 0.4),
		_tone(784.0, 0.09, "square", 0.4),
		_tone(1046.0, 0.14, "square", 0.4),
	]))

static func make_purchase() -> AudioStreamWAV:
	return _make_wav(_concat([_tone(500.0, 0.05, "sine", 0.35), _tone(750.0, 0.09, "sine", 0.35)]))

static func make_error() -> AudioStreamWAV:
	return _make_wav(_concat([_tone(160.0, 0.09, "square", 0.3), _tone(110.0, 0.12, "square", 0.3)]))

static func make_mine() -> AudioStreamWAV:
	# A rockier, longer-noised cousin of make_hit() -- a low crack plus a
	# sharper/longer noise burst (the shatter), then a couple of loose
	# fragment "clinks" as the rubble settles.
	var crack := _mix([_tone(65.0, 0.09, "square", 0.45), _tone(0.0, 0.14, "noise", 0.4)])
	var clink1 := _tone(1200.0, 0.04, "square", 0.2)
	var clink2 := _tone(950.0, 0.05, "square", 0.18)
	return _make_wav(_concat([crack, clink1, clink2]))

static func make_shield_block() -> AudioStreamWAV:
	# A bright metallic clang -- higher and shorter than make_hit(), with a
	# quick harmonic overtone mixed in for a "struck metal" timbre instead
	# of a dull thump.
	var ring := _tone(700.0, 0.07, "square", 0.4)
	var overtone := _tone(1400.0, 0.05, "square", 0.22)
	return _make_wav(_mix([ring, overtone]))

static func make_shield_knockback() -> AudioStreamWAV:
	# The block's clang, immediately followed by a forceful low
	# thump-plus-noise shove -- distinct from the clang alone so a knockback
	# block reads as heavier than a plain one.
	var clang := _mix([_tone(700.0, 0.06, "square", 0.35), _tone(1400.0, 0.04, "square", 0.2)])
	var shove := _mix([_tone(55.0, 0.13, "square", 0.45), _tone(0.0, 0.1, "noise", 0.25)])
	return _make_wav(_concat([clang, shove]))

static func make_fae_spawn() -> AudioStreamWAV:
	# A tiny ascending sparkle -- sine instead of make_shard()'s square, for
	# a softer, more magical timbre appropriate to a fairy popping into
	# existence rather than a hard currency pickup.
	return _make_wav(_concat([
		_tone(1046.0, 0.06, "sine", 0.3),
		_tone(1568.0, 0.06, "sine", 0.3),
		_tone(2093.0, 0.1, "sine", 0.3),
	]))

static func make_heal() -> AudioStreamWAV:
	# A gentle rising sine arpeggio -- soft and warm, distinct from buff's
	# snappier square tones below.
	return _make_wav(_concat([
		_tone(440.0, 0.1, "sine", 0.35),
		_tone(554.0, 0.1, "sine", 0.35),
		_tone(659.0, 0.16, "sine", 0.35),
	]))

static func make_buff() -> AudioStreamWAV:
	# A quick, punchy square-wave power-up sting -- brighter and snappier
	# than heal's soft sine arpeggio, to read as an offensive boost rather
	# than a recovery.
	return _make_wav(_concat([
		_tone(392.0, 0.06, "square", 0.35),
		_tone(523.0, 0.06, "square", 0.35),
		_tone(659.0, 0.1, "square", 0.35),
	]))
