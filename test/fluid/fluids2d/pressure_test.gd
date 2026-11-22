extends GdUnitTestSuite

const Pressure = preload("res://fluid/fluids2d/pressure.gd")
const TEST_SIZE := Vector2i(8, 8)
const TIMEOUT_MS := 5000
const TOLERANCE := 0.005


func test_zero_divergence_and_pressure_stays_zero() -> void:
	var results := await _run_pressure(
		_constant_image(TEST_SIZE, 0.0), _constant_image(TEST_SIZE, 0.0), 1
	)
	if results.is_empty():
		return
	_assert_pressure(results[0], func(_x: int, _y: int) -> float: return 0.0)


func test_constant_pressure_without_divergence_is_unchanged() -> void:
	var results := await _run_pressure(
		_constant_image(TEST_SIZE, 0.0), _constant_image(TEST_SIZE, 3.0), 2
	)
	if results.is_empty():
		return
	_assert_pressure(results[0], func(_x: int, _y: int) -> float: return 3.0)


func test_one_iteration_from_zero_is_negative_quarter_divergence() -> void:
	var divergence := _ramp(TEST_SIZE)
	var results := await _run_pressure(divergence, _constant_image(TEST_SIZE, 0.0), 1)
	if results.is_empty():
		return
	_assert_pressure(results[0], func(x: int, y: int) -> float:
		return -0.25 * _ramp_value(x, y)
	)


func test_two_iterations_spread_interior_point() -> void:
	var divergence := _constant_image(TEST_SIZE, 0.0)
	divergence.set_pixel(3, 3, Color(16.0, 0.0, 0.0, 1.0))
	var results := await _run_pressure(divergence, _constant_image(TEST_SIZE, 0.0), 2)
	if results.is_empty():
		return
	_assert_pressure(results[0], func(x: int, y: int) -> float:
		if x == 3 and y == 3:
			return -4.0
		if absi(x - 3) + absi(y - 3) == 1:
			return -1.0
		return 0.0
	)


func test_two_iterations_at_corner_use_clamped_neighbours() -> void:
	var divergence := _constant_image(TEST_SIZE, 0.0)
	divergence.set_pixel(0, 0, Color(16.0, 0.0, 0.0, 1.0))
	var results := await _run_pressure(divergence, _constant_image(TEST_SIZE, 0.0), 2)
	if results.is_empty():
		return
	_assert_pressure(results[0], func(x: int, y: int) -> float:
		if x == 0 and y == 0:
			return -6.0
		if (x == 1 and y == 0) or (x == 0 and y == 1):
			return -1.0
		return 0.0
	)


func test_size_not_divisible_by_workgroup_size() -> void:
	var size := Vector2i(9, 11)
	var results := await _run_pressure(_ramp(size), _constant_image(size, 0.0), 1)
	if results.is_empty():
		return
	_assert_pressure(results[0], func(x: int, y: int) -> float:
		return -0.25 * _ramp_value(x, y)
	)


func _constant_image(size: Vector2i, value: float) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBAH)
	image.fill(Color(value, 0.0, 0.0, 1.0))
	return image


# Distinct, signed value per pixel so a wrong pixel or channel is visible.
func _ramp_value(x: int, y: int) -> float:
	return float(x) - 0.5 * float(y)


func _ramp(size: Vector2i) -> Image:
	var image := _constant_image(size, 0.0)
	for y in range(size.y):
		for x in range(size.x):
			image.set_pixel(x, y, Color(_ramp_value(x, y), 0.0, 0.0, 1.0))
	return image


func _assert_pressure(image: Image, expected: Callable) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var value: float = expected.call(x, y)
			var pixel := image.get_pixel(x, y)
			var location := "Pixel (%d, %d)" % [x, y]
			assert_float(pixel.r).override_failure_message(
				"%s: expected pressure %s, got %s" % [location, value, pixel.r]
			).is_equal_approx(value, TOLERANCE)
			assert_float(pixel.g).is_equal_approx(0.0, TOLERANCE)
			assert_float(pixel.b).is_equal_approx(0.0, TOLERANCE)
			assert_float(pixel.a).override_failure_message(
				"%s: expected alpha 1, got %s" % [location, pixel.a]
			).is_equal_approx(1.0, TOLERANCE)


func _run_pressure(divergence: Image, pressure: Image, iterations: int) -> Array[Image]:
	var state := {"finished": false, "results": [], "error": ""}
	RenderingServer.call_on_render_thread(
		_run_on_render_thread.bind(divergence, pressure, iterations, state)
	)
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while not state.finished and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	assert_bool(state.finished).override_failure_message(
		"Timed out waiting for the pressure GPU test; check Godot's error output."
	).is_true()
	if not state.finished:
		return []
	assert_str(state.error).is_empty()
	if not state.error.is_empty():
		return []

	var results: Array[Image] = []
	results.assign(state.results)
	assert_int(results.size()).is_equal(1)
	return results


# GPU creation, uploads, dispatches, swaps, readbacks and cleanup stay together.
func _run_on_render_thread(divergence: Image, pressure: Image, iterations: int, state: Dictionary) -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		_receive_result.call_deferred(state, [], "No RenderingDevice available.")
		return

	var size := divergence.get_size()
	var fields := FluidFields.new()
	fields.initialize(Vector2(size))
	var solver := Pressure.new(fields)
	solver.iterations = iterations
	var results: Array[Image] = []
	var message := ""
	# A sentinel ensures an unwritten output pixel fails even a zero-field test.
	var sentinel := Image.create(size.x, size.y, false, Image.FORMAT_RGBAH)
	sentinel.fill(Color(99.0, 99.0, 99.0, 0.0))

	var upload_error := rd.texture_update(
		fields.divergence.get_texture_rd(), 0, divergence.get_data()
	)
	if upload_error == OK:
		upload_error = rd.texture_update(
			fields.pressure.get_texture_rd(), 0, pressure.get_data()
		)
	if upload_error == OK:
		upload_error = rd.texture_update(
			fields.pressure.get_write_texture_rd(), 0, sentinel.get_data()
		)

	if upload_error != OK:
		message = "Texture upload failed: %s" % error_string(upload_error)
	else:
		solver.process(0.0)
		var bytes := rd.texture_get_data(fields.pressure.get_texture_rd(), 0)
		if bytes.is_empty():
			message = "Pressure readback returned no data."
		else:
			results.append(Image.create_from_data(
				size.x, size.y, false, Image.FORMAT_RGBAH, bytes
			))

	solver._compute_shader.release()
	solver._compute_shader._node = null
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
