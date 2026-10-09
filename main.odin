package main

import "base:runtime"
import "core:log"
import "core:math/rand"
import "core:strings"
import gl "vendor:OpenGL"
import b2 "vendor:box2d"
import sdl "vendor:sdl2"

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720
SCREEN_FPS :: 60
SCREEN_TICKS_PER_FRAME :: 1000 / SCREEN_FPS
BODY_COUNT :: 300
SCALE :: 50.0
WORLD_WIDTH :: f32(SCREEN_WIDTH) / SCALE
WORLD_HEIGHT :: f32(SCREEN_HEIGHT) / SCALE
MIN_RADIUS :: 0.1
MAX_RADIUS :: 0.275
MOUSE_STRENGTH :: 20.0

app: Application_Data

vertex_source := #load("shader.vert", string)
fragment_source := #load("shader.frag", string)

Application_Data :: struct {
	window:     ^sdl.Window,
	world_id:   b2.WorldId,
	bodies:     [BODY_COUNT]b2.BodyId,
	shapes:     [BODY_COUNT]b2.ShapeId,
	gl_context: sdl.GLContext,
	vao:        u32,
	mouse_pos:  b2.Vec2,
	mouse_down: bool,
}

sdl_log :: proc "c" (
	userdata: rawptr,
	category: sdl.LogCategory,
	priority: sdl.LogPriority,
	message: cstring,
) {
	context = (transmute(^runtime.Context)userdata)^
	level: log.Level

	switch priority {
	case .NUM, .DEFAULT, .VERBOSE, .DEBUG:
		level = .Debug
	case .INFO:
		level = .Info
	case .WARN:
		level = .Warning
	case .ERROR:
		level = .Error
	case .CRITICAL:
		level = .Fatal
	}

	log.logf(level, "SDL {}: {}", category, message)
}

get_assert :: proc(ok: bool, name: string, get: proc "cdecl" () -> cstring) {
	if !ok do log.panicf("%v error: %v", name, get())
}

sdl_assert :: proc(ok: bool) {
	get_assert(ok, "SDL", sdl.GetError)
}

init :: proc() {
	@(static) sdl_log_context: runtime.Context
	sdl_log_context = context
	sdl_log_context.logger.options -= {.Short_File_Path, .Line, .Procedure}
	sdl.LogSetAllPriority(.VERBOSE)
	sdl.LogSetOutputFunction(sdl_log, &sdl_log_context)

	sdl_assert(sdl.Init({.VIDEO}) == 0)

	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 3)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 3)
	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl.GLprofile.CORE))

	app.window = sdl.CreateWindow(
		"Window",
		sdl.WINDOWPOS_UNDEFINED,
		sdl.WINDOWPOS_UNDEFINED,
		SCREEN_WIDTH,
		SCREEN_HEIGHT,
		{.SHOWN, .OPENGL},
	); sdl_assert(app.window != nil)

	app.gl_context = sdl.GL_CreateContext(app.window); sdl_assert(app.gl_context != nil)

	gl.load_up_to(3, 3, sdl.gl_set_proc_address)

	gl.GenVertexArrays(1, &app.vao)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	log.debug("Initializing simulation...")

	world_def := b2.DefaultWorldDef()
	world_def.gravity = {0, -9.8}
	app.world_id = b2.CreateWorld(world_def)

	floor_body_def := b2.DefaultBodyDef()
	floor_body_def.type = .staticBody
	floor_body_def.position = {0, -WORLD_HEIGHT / 2.0}
	floor_body := b2.CreateBody(app.world_id, floor_body_def)
	floor_shape_def := b2.DefaultShapeDef()
	floor_polygon := b2.MakeBox(WORLD_WIDTH / 2, 0.1)
	floor := b2.CreatePolygonShape(floor_body, floor_shape_def, floor_polygon)

	ceiling_body_def := b2.DefaultBodyDef()
	ceiling_body_def.type = .staticBody
	ceiling_body_def.position = {0, WORLD_HEIGHT / 2.0}
	ceiling_body := b2.CreateBody(app.world_id, ceiling_body_def)
	ceiling_shape_def := b2.DefaultShapeDef()
	ceiling_polygon := b2.MakeBox(WORLD_WIDTH / 2, 0.1)
	ceiling := b2.CreatePolygonShape(ceiling_body, ceiling_shape_def, ceiling_polygon)

	left_wall_body_def := b2.DefaultBodyDef()
	left_wall_body_def.type = .staticBody
	left_wall_body_def.position = {-WORLD_WIDTH / 2.0, 0}
	left_wall_body := b2.CreateBody(app.world_id, left_wall_body_def)
	left_wall_shape_def := b2.DefaultShapeDef()
	left_wall_polygon := b2.MakeBox(0.1, WORLD_HEIGHT / 2.0)
	left_wall := b2.CreatePolygonShape(left_wall_body, left_wall_shape_def, left_wall_polygon)

	right_wall_body_def := b2.DefaultBodyDef()
	right_wall_body_def.type = .staticBody
	right_wall_body_def.position = {WORLD_WIDTH / 2.0, 0}
	right_wall_body := b2.CreateBody(app.world_id, right_wall_body_def)
	right_wall_shape_def := b2.DefaultShapeDef()
	right_wall_polygon := b2.MakeBox(0.1, WORLD_HEIGHT / 2.0)
	right_wall := b2.CreatePolygonShape(right_wall_body, right_wall_shape_def, right_wall_polygon)

	for i in 0 ..< BODY_COUNT {
		body_def := b2.DefaultBodyDef()
		body_def.type = .dynamicBody
		body_def.position = {rand.float32() * 2.0 - 1.0, rand.float32() * 2.0 - 1.0}
		app.bodies[i] = b2.CreateBody(app.world_id, body_def)

		shape_def := b2.DefaultShapeDef()

		circle := b2.Circle {
			center = {0, 0},
			radius = MIN_RADIUS + rand.float32() * (MAX_RADIUS - MIN_RADIUS),
		}
		app.shapes[i] = b2.CreateCircleShape(app.bodies[i], shape_def, circle)
	}
}

main :: proc() {
	context.logger = log.create_console_logger()

	init()

	vertex := compile_shader(gl.VERTEX_SHADER, vertex_source)
	fragment := compile_shader(gl.FRAGMENT_SHADER, fragment_source)

	program := gl.CreateProgram()

	gl.AttachShader(program, vertex)
	gl.AttachShader(program, fragment)

	gl.LinkProgram(program)

	gl.DeleteShader(vertex)
	gl.DeleteShader(fragment)

	ball_location := gl.GetUniformLocation(program, "balls")
	radii_location := gl.GetUniformLocation(program, "radii")

	event: sdl.Event

	fps_timer := new_timer()
	cap_timer := new_timer()

	counted_frames := u32(0)
	start_timer(&fps_timer)

	main_loop: for {
		start_timer(&cap_timer)

		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				break main_loop
			case .KEYDOWN:
				#partial switch event.key.keysym.sym {
				case .ESCAPE:
					break main_loop
				}
			case .MOUSEBUTTONDOWN:
				if event.button.button == sdl.BUTTON_LEFT {
					app.mouse_down = true
				}
			case .MOUSEBUTTONUP:
				if event.button.button == sdl.BUTTON_LEFT {
					app.mouse_down = false
				}
			case .MOUSEMOTION:
				mouse_x := f32(event.motion.x)
				mouse_y := f32(event.motion.y)

				app.mouse_pos = {
					(mouse_x - SCREEN_WIDTH / 2) / SCALE,
					(SCREEN_HEIGHT / 2 - mouse_y) / SCALE,
				}
			}
		}

		avg_fps := f32(counted_frames) / (f32(get_time(&fps_timer)) / 1000.0)
		if avg_fps > 2000000 {
			avg_fps = 0
		}

		if app.mouse_down {
			for body in app.bodies {
				position := b2.Body_GetPosition(body)
				direction := app.mouse_pos - position
				distance := b2.Length(direction)

				if distance > 0.01 {
					direction = direction / distance
				}

				force := direction * MOUSE_STRENGTH

				b2.Body_ApplyForceToCenter(body, force, true)
			}
		}

		b2.World_Step(app.world_id, 1 / f32(SCREEN_FPS), 4)

		positions: [BODY_COUNT][2]f32
		radii: [BODY_COUNT]f32

		for shape, i in app.shapes {
			body := b2.Shape_GetBody(shape)
			pos := b2.Body_GetPosition(body)

			positions[i] = {pos.x * SCALE + SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 - pos.y * SCALE}

			radii[i] = b2.Shape_GetCircle(shape).radius * SCALE
		}

		gl.Clear(gl.COLOR_BUFFER_BIT)
		gl.Viewport(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
		gl.ClearColor(0.05, 0.05, 0.05, 1.0)

		gl.UseProgram(program)

		gl.Uniform2fv(ball_location, BODY_COUNT, &positions[0].x)
		gl.Uniform1fv(radii_location, BODY_COUNT, &radii[0])

		gl.BindVertexArray(app.vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 3)

		sdl.GL_SwapWindow(app.window)
		counted_frames += 1

		frame_ticks := get_time(&cap_timer)
		if frame_ticks < SCREEN_TICKS_PER_FRAME {
			sdl.Delay(SCREEN_TICKS_PER_FRAME - frame_ticks)
		}
	}

	exit()
}

compile_shader :: proc(type: u32, source: string) -> u32 {
	shader := gl.CreateShader(type)

	csource := strings.clone_to_cstring(source)

	gl.ShaderSource(shader, 1, &csource, nil)

	gl.CompileShader(shader)

	success: i32
	gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success)

	if success == 0 {
		panic("Shader compilation failed")
	}
	return shader
}

exit :: proc() {
	log.debug("Closing...")

	sdl.DestroyWindow(app.window)
	app.window = nil

	sdl.Quit()

	b2.DestroyWorld(app.world_id)
	app.world_id = b2.nullWorldId
}
