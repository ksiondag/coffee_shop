extends GdUnitTestSuite

const GradientSubtract = preload("res://fluid/fluids2d/gradient_subtract.gd")
const TEST_SIZE := Vector2i(8, 8)
const TIMEOUT_MS := 5000
const TOLERANCE := 0.005
# Non-zero so a pass that ignores the velocity input fails.
const INITIAL := Vector2(1.0, -2.0)


func test_zero_pressure_preserves_velocity() -> void:
	var results := await _run_gradient_subtract(
		_velocity_image(TEST_SIZE, INITIAL), [_pressure_constant(TEST_SIZE, 0.0)]
	)
	if results.is_empty():
		return
	_assert_velocity(results[0], func(_x: int, _y: int) -> Vector2: return INITIAL)


func test_constant_pressure_preserves_velocity() -> void:
	# Edge pixels only stay unchanged if clamped neighbours repeat the edge value
	var results := await _run_gradient_subtract(
		_velocity_image(TEST_SIZE, INITIAL), [_pressure_constant(TEST_SIZE, 5.0)]
	)
	if results.is_empty():
		return
	_assert_velocity(results[0], func(_x: int, _y: int) -> Vector2: return INITIAL)


func test_pressure_increasing_across_x_reduces_vx() -> void:
	var results := await _run_gradient_subtract(
		_velocity_image(TEST_SIZE, INITIAL), [_pressure_ramp(TEST_SIZE, true)]
	)
	if results.is_empty():
		return
	_assert_velocity(results[0], func(x: int, _y: int) -> Vector2:
		return INITIAL - Vector2(_ramp_gradient(x, TEST_SIZE.x), 0.0)
	)


func test_pressure_increasing_across_y_reduces_vy() -> void:
	var results := await _run_gradient_subtract(
		_velocity_image(TEST_SIZE, INITIAL), [_pressure_ramp(TEST_SIZE, false)]
	)
	if results.is_empty():
		return
	_assert_velocity(results[0], func(_x: int, y: int) -> Vector2:
		return INITIAL - Vector2(0.0, _ramp_gradient(y, TEST_SIZE.y))
	)


func test_pressure_point_pushes_neighbours_away() -> void:
	var pressure := _pressure_constant(TEST_SIZE, 0.0)
	pressure.set_pixel(3, 3, Color(4.0, 0.0, 0.0, 1.0))
	var results := await _run_gradient_subtract(
		_velocity_image(TEST_SIZE, INITIAL), [pressure]
	)
	if results.is_empty():
		return
	_assert_velocity(results[0], func(x: int, y: int) -> Vector2:
		if x == 2 and y == 3:
			return INITIAL + Vector2(-4.0, 0.0)
		if x == 4 and y == 3:
			return INITIAL + Vector2(4.0, 0.0)
		if x == 3 and y == 2:
			return INITIAL + Vector2(0.0, -4.0)
		if x == 3 and y == 4:
			return INITIAL + Vector2(0.0, 4.0)
		return INITIAL
	)


func test_size_not_divisible_by_workgroup_size() -> void:
	var size := Vector2i(9, 11)
	var results := await _run_gradient_subtract(
		_velocity_image(size, INITIAL), [_pressure_ramp(size, false)]
	)
	if results.is_empty():
		return
	_assert_velocity(results[0], func(_x: int, y: int) -> Vector2:
		return INITIAL - Vector2(0.0, _ramp_gradient(y, size.y))
	)


func test_consecutive_passes_follow_velocity_swaps() -> void:
	var results := await _run_gradient_subtract(
		_velocity_image(TEST_SIZE, INITIAL),
		[_pressure_ramp(TEST_SIZE, true), _pressure_ramp(TEST_SIZE, false)]
	)
	if results.size() != 2:
		return
	_assert_velocity(results[0], func(x: int, _y: int) -> Vector2:
		return INITIAL - Vector2(_ramp_gradient(x, TEST_SIZE.x), 0.0)
	)
	_assert_velocity(results[1], func(x: int, y: int) -> Vector2:
		return INITIAL - Vector2(
			_ramp_gradient(x, TEST_SIZE.x), _ramp_gradient(y, TEST_SIZE.y)
		)
	)


func _velocity_image(size: Vector2i, velocity: Vector2) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBAH)
	image.fill(Color(velocity.x, velocity.y, 0.0, 1.0))
	return image


func _pressure_constant(size: Vector2i, value: float) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBAH)
	image.fill(Color(value, 0.0, 0.0, 1.0))
	return image


# p = x or p = y
func _pressure_ramp(size: Vector2i, across_x: bool) -> Image:
	var image := _pressure_constant(size, 0.0)
	for y in range(size.y):
		for x in range(size.x):
			var coordinate := x if across_x else y
			image.set_pixel(x, y, Color(float(coordinate), 0.0, 0.0, 1.0))
	return image


func _ramp_gradient(coordinate: int, length: int) -> float:
	if coordinate == 0 or coordinate == length - 1:
		return 1.0
	return 2.0


func _assert_velocity(image: Image, expected: Callable) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var value: Vector2 = expected.call(x, y)
			var pixel := image.get_pixel(x, y)
			var location := "Pixel (%d, %d)" % [x, y]
			assert_float(pixel.r).override_failure_message(
				"%s: expected vx %s, got %s" % [location, value.x, pixel.r]
			).is_equal_approx(value.x, TOLERANCE)
			assert_float(pixel.g).override_failure_message(
				"%s: expected vy %s, got %s" % [location, value.y, pixel.g]
			).is_equal_approx(value.y, TOLERANCE)
			assert_float(pixel.b).is_equal_approx(0.0, TOLERANCE)
			assert_float(pixel.a).override_failure_message(
				"%s: expected alpha 1, got %s" % [location, pixel.a]
			).is_equal_approx(1.0, TOLERANCE)


func _run_gradient_subtract(velocity: Image, pressures: Array[Image]) -> Array[Image]:
	var state := {"finished": false, "results": [], "error": ""}
	RenderingServer.call_on_render_thread(
		_run_on_render_thread.bind(velocity, pressures, state)
	)
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while not state.finished and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	assert_bool(state.finished).override_failure_message(
		"Timed out waiting for the gradient subtract GPU test; check Godot's error output."
	).is_true()
	if not state.finished:
		return []
	assert_str(state.error).is_empty()
	if not state.error.is_empty():
		return []

	var results: Array[Image] = []
	results.assign(state.results)
	assert_int(results.size()).is_equal(pressures.size())
	return results


# GPU creation, uploads, dispatches, swaps, readbacks and cleanup stay together.
func _run_on_render_thread(velocity: Image, pressures: Array[Image], state: Dictionary) -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		_receive_result.call_deferred(state, [], "No RenderingDevice available.")
		return

	var size := velocity.get_size()
	var fields := FluidFields.new()
	fields.initialize(Vector2(size))
	var gradient_subtract := GradientSubtract.new(fields)
	var results: Array[Image] = []
	var message := ""

	var sentinel := Image.create(size.x, size.y, false, Image.FORMAT_RGBAH)
	sentinel.fill(Color(99.0, 99.0, 99.0, 0.0))

	var upload_error := rd.texture_update(
		fields.velocity.get_texture_rd(), 0, velocity.get_data()
	)
	for pressure in pressures:
		if upload_error == OK:
			upload_error = rd.texture_update(
				fields.pressure.get_texture_rd(), 0, pressure.get_data()
			)
		if upload_error == OK:
			upload_error = rd.texture_update(
				fields.velocity.get_write_texture_rd(), 0, sentinel.get_data()
			)
		if upload_error != OK:
			message = "Texture upload failed: %s" % error_string(upload_error)
			break

		var previous_read := fields.velocity.get_texture_rd()
		gradient_subtract.process(0.0)
		if previous_read == fields.velocity.get_texture_rd():
			message = "GradientSubtract did not swap the velocity textures."
			break

		var bytes := rd.texture_get_data(fields.velocity.get_texture_rd(), 0)
		if bytes.is_empty():
			message = "Gradient subtract readback returned no data."
			break
		results.append(Image.create_from_data(
			size.x, size.y, false, Image.FORMAT_RGBAH, bytes
		))

	gradient_subtract._compute_shader.release()
	gradient_subtract._compute_shader._node = null
	fields.dye.release()
	fields.velocity.release()
	fields.divergence.release()
	fields.curl.release()
	fields.pressure.release()
	_receive_result.call_deferred(state, results, message)


func _receive_result(state: Dictionary, results: Array, message: String) -> void:
	state.results = results
	state.error = message
	state.finished = true
