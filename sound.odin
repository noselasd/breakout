package main

import "core:c"
import rl "vendor:raylib"


bounce_sound: rl.Sound
destroy_sound: rl.Sound

init_sound :: proc() {
	// compile-time loading of raw f32 samples
	bounce_samples := #load("samples/bounce.raw", []f32)
	destroy_samples := #load("samples/destroy.raw", []f32)

	wave: rl.Wave
	wave.sampleRate = 44100
	wave.sampleSize = 32 // 32 bits = 4 bytes per sample (f32)
	wave.channels = 1 // Mono
	wave.frameCount = c.uint(len(bounce_samples))
	wave.data = rawptr(&bounce_samples[0])
	bounce_sound = rl.LoadSoundFromWave(wave)

	wave.frameCount = c.uint(len(destroy_samples))
	wave.data = rawptr(&destroy_samples[0])
	destroy_sound = rl.LoadSoundFromWave(wave)
}
