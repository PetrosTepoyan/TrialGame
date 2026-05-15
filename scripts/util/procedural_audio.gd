class_name ProceduralAudio
extends Object

# Synthesizes simple AudioStreamWAV blips at runtime so the audio system always
# has something to play when a licensed .ogg is missing. Pure sine partials with
# an exponential decay envelope — small footprint, cheap to keep in memory.
#
# Everything here is intentionally additive: callers should still prefer real
# samples loaded from disk and only fall back to these synthesized blips when
# ResourceLoader.exists() returns false.

const SAMPLE_RATE: int = 22050

# Equal-tempered frequencies for common pitches we reuse across blips.
const HZ_C5: float = 523.25
const HZ_E5: float = 659.25
const HZ_G5: float = 783.99
const HZ_A5: float = 880.00
const HZ_C6: float = 1046.50
const HZ_E6: float = 1318.51
const HZ_G6: float = 1567.98
const HZ_A4: float = 440.00
const HZ_F4: float = 349.23
const HZ_D5: float = 587.33
const HZ_B4: float = 493.88

# --- Public factories --------------------------------------------------------

static func ui_click() -> AudioStreamWAV:
	# Bright triad blip — short and snappy so it works under repeated taps.
	return _make_chord([HZ_C5, HZ_E5, HZ_G5], 0.07, 0.5)

static func ui_hover() -> AudioStreamWAV:
	# Single, softer mid tone — meant to whisper, not punch.
	return _make_chord([HZ_E5], 0.05, 0.28)

static func panel_open() -> AudioStreamWAV:
	# Upward sweep — two stacked partials with a quick decay.
	return _make_sweep(HZ_C5, HZ_C6, 0.16, 0.42)

static func panel_close() -> AudioStreamWAV:
	# Downward sweep — inverse of panel_open.
	return _make_sweep(HZ_C6, HZ_C5, 0.14, 0.40)

static func combo_zap(level: int) -> AudioStreamWAV:
	# Bright stacked chord; higher level adds an octave layer.
	var freqs: Array[float] = [HZ_C5, HZ_E5, HZ_G5]
	if level >= 2:
		freqs.append(HZ_C6)
	if level >= 3:
		freqs.append(HZ_E6)
		freqs.append(HZ_G6)
	var duration: float = 0.18 + 0.06 * float(min(level, 3))
	var amp: float = 0.45 + 0.06 * float(min(level, 3))
	return _make_chord(freqs, duration, amp)

static func victory_sting() -> AudioStreamWAV:
	# Two-note rising fanfare: G5 then C6.
	return _make_two_note(HZ_G5, HZ_C6, 0.20, 0.30, 0.55)

static func defeat_sting() -> AudioStreamWAV:
	# Two-note falling sting: A4 then F4.
	return _make_two_note(HZ_A4, HZ_F4, 0.22, 0.32, 0.50)

static func status_blip(kind_index: int) -> AudioStreamWAV:
	# Different signature per status kind. Map roughly to ordinal so callers can
	# pass StatusEffect.Kind directly.
	match kind_index:
		0: # BURN — warm, rising
			return _make_chord([HZ_E5, HZ_A5], 0.10, 0.40)
		1: # SWARM — buzzy stack
			return _make_chord([HZ_D5, HZ_E5, HZ_G5], 0.13, 0.35)
		2: # COLD — high, thin
			return _make_chord([HZ_C6, HZ_E6], 0.12, 0.32)
		3: # BLEED — low, repeating
			return _make_chord([HZ_F4, HZ_A4], 0.10, 0.45)
		4: # STUN — bell-like single
			return _make_chord([HZ_B4, HZ_D5, HZ_G5], 0.18, 0.42)
		5: # DEFENSE_DEBUFF — minor flavor
			return _make_chord([HZ_C5, HZ_F4], 0.13, 0.38)
	return _make_chord([HZ_C5], 0.08, 0.30)

# --- Builders ----------------------------------------------------------------

static func _make_chord(freqs: Array, duration: float, amplitude: float) -> AudioStreamWAV:
	var samples: int = max(1, int(duration * float(SAMPLE_RATE)))
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = _envelope(t, duration)
		var s: float = 0.0
		for f_v in freqs:
			var f: float = float(f_v)
			s += sin(TAU * f * t)
		s = s / float(max(1, freqs.size()))
		s = s * amplitude * env
		_write_sample16(data, i, s)
	return _wrap(data)

static func _make_sweep(start_hz: float, end_hz: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var samples: int = max(1, int(duration * float(SAMPLE_RATE)))
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var k: float = float(i) / float(samples)
		var hz: float = lerp(start_hz, end_hz, k)
		phase += TAU * hz / float(SAMPLE_RATE)
		var env: float = _envelope(t, duration)
		var s: float = sin(phase) * amplitude * env
		_write_sample16(data, i, s)
	return _wrap(data)

static func _make_two_note(hz_a: float, hz_b: float, dur_a: float, dur_b: float, amplitude: float) -> AudioStreamWAV:
	var samples_a: int = max(1, int(dur_a * float(SAMPLE_RATE)))
	var samples_b: int = max(1, int(dur_b * float(SAMPLE_RATE)))
	var total: int = samples_a + samples_b
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in range(samples_a):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = _envelope(t, dur_a)
		var s: float = sin(TAU * hz_a * t) * amplitude * env
		_write_sample16(data, i, s)
	for j in range(samples_b):
		var t2: float = float(j) / float(SAMPLE_RATE)
		var env2: float = _envelope(t2, dur_b)
		var s2: float = sin(TAU * hz_b * t2) * amplitude * env2
		_write_sample16(data, samples_a + j, s2)
	return _wrap(data)

static func _envelope(t: float, duration: float) -> float:
	# Quick attack, exponential decay. Keeps blips tight and click-free.
	var attack: float = 0.005
	if t < attack:
		return t / attack
	var k: float = (t - attack) / max(0.0001, duration - attack)
	return exp(-3.2 * k)

static func _write_sample16(data: PackedByteArray, index: int, sample: float) -> void:
	var clamped: float = clamp(sample, -1.0, 1.0)
	var v: int = int(clamped * 32767.0)
	if v < 0:
		v += 65536
	data[index * 2] = v & 0xFF
	data[index * 2 + 1] = (v >> 8) & 0xFF

static func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SAMPLE_RATE
	s.stereo = false
	s.loop_mode = AudioStreamWAV.LOOP_DISABLED
	s.data = data
	return s
