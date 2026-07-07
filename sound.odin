package main

import "core:c"
import rl "vendor:raylib"


sound_bounce: rl.Sound
sound_destroy: rl.Sound
sound_died: rl.Sound

init_sound :: proc() {
	// compile-time loading of raw f32 samples
	bounce_samples := #load("samples/bounce.raw", []f32)
	destroy_samples := #load("samples/destroy.raw", []f32)
	died_samples := #load("samples/died.raw", []f32)

	wave: rl.Wave
	wave.sampleRate = 44100
	wave.sampleSize = 32 // 32 bits = 4 bytes per sample (f32)
	wave.channels = 1 // Mono
	wave.frameCount = c.uint(len(bounce_samples))
	wave.data = rawptr(&bounce_samples[0])
	sound_bounce = rl.LoadSoundFromWave(wave)

	wave.frameCount = c.uint(len(destroy_samples))
	wave.data = rawptr(&destroy_samples[0])
	sound_destroy = rl.LoadSoundFromWave(wave)

	wave.frameCount = c.uint(len(died_samples))
	wave.data = rawptr(&died_samples[0])
	sound_died = rl.LoadSoundFromWave(wave)
}
