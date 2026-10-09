package main

import sdl "vendor:sdl2"

Timer :: struct {
	start_ticks:  u32,
	paused_ticks: u32,
	paused:       bool,
	started:      bool,
}

new_timer :: proc() -> Timer {
	return {start_ticks = 0, paused_ticks = 0, paused = false, started = false}
}

start_timer :: proc(timer: ^Timer) {
	timer.started = true
	timer.paused = false

	timer.start_ticks = sdl.GetTicks()
	timer.paused_ticks = 0
}

stop_timer :: proc(timer: ^Timer) {
	timer.started = false
	timer.paused = false

	timer.start_ticks = 0
	timer.paused_ticks = 0
}

pause_timer :: proc(timer: ^Timer) {
	if timer.started && !timer.paused {
		timer.paused = true

		timer.paused_ticks = sdl.GetTicks() - timer.start_ticks
		timer.start_ticks = 0
	}
}

unpause_timer :: proc(timer: ^Timer) {
	if timer.started && timer.paused {
		timer.paused = false

		timer.start_ticks = sdl.GetTicks() - timer.paused_ticks
		timer.paused_ticks = 0
	}
}

get_time :: proc(timer: ^Timer) -> u32 {
	if timer.started {
		if timer.paused {
			return timer.paused_ticks
		}
		return sdl.GetTicks() - timer.start_ticks
	}

	return 0
}

is_timer_started :: proc(timer: ^Timer) -> bool {
	return timer.started
}

is_timer_paused :: proc(timer: ^Timer) -> bool {
	return timer.paused
}
