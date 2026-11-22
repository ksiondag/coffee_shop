extends GdUnitTestSuite

const PressureDecay = preload("res://fluid/fluids2d/pressure_decay.gd")
const TEST_SIZE := Vector2i(8, 8)
const TIMEOUT_MS := 5000
# Half-float textures: ~3 significant digits for values up to ~10.
const TOLERANCE := 0.01
const DECAY := 0.8


func test_zero_pressure_stays_zero() -> void:
	var results := await _run_decay(_constant_image(TEST_SIZE, 0.0), 1)
	if results.is_empty():
		return
	_assert_pressure(results[0], func(_x: int, _y: int) -> float: return 0.0)


func test_constant_pressure_is_scaled() -> void:
	var results := await _run_decay(_constant_image(TEST_SIZE, -5.0), 1)
	if results.is_empty():
		return
	_assert_pressure(results[0], func(_x: int, _y: int) -> float: return -5.0 * DECAY)


func test_pressure_ramp_is_scaled_per_pixel() -> void:
	var results := await _run_decay(_ramp(TEST_SIZE), 1)
	if results.is_empty():
		return
	_assert_pressure(results[0], func(x: int, y: int) -> float:
		return _ramp_value(x, y) * DECAY
	)


func test_size_not_divisible_by_workgroup_size() -> void:
	var size := Vector2i(9, 11)
	var results := await _run_decay(_ramp(size), 1)
	if results.is_empty():
		return
	_assert_pressure(results[0], func(x: int, y: int) -> float:
		return _ramp_value(x, y) * DECAY
	)


func test_second_dispatch_reads_first_result_after_swap() -> void:
	var results := await _run_decay(_ramp(TEST_SIZE), 2)
	if results.size() != 2:
		return
	_assert_pressure(results[0], func(x: int, y: int) -> float:
		return _ramp_value(x, y) * DECAY
	)
	_assert_pressure(results[1], func(x: int, y: int) -> float:
		return _ramp_value(x, y) * DECAY * DECAY
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


func _run_decay(pressure: Image, dispatches: int) -> Array[Image]:
	var state := {"finished": false, "results": [], "error": ""}
	RenderingServer.call_on_render_thread(
		_run_on_render_thread.bind(pressure, dispatches, state)
	)
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while not state.finished and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	assert_bool(state.finished).override_failure_message(
		"Timed out waiting for the pressure decay GPU test; check Godot's error output."
	).is_true()
	if not state.finished:
		return []
	assert_str(state.error).is_empty()
	if not state.error.is_empty():
		return []

	var results: Array[Image] = []
	results.assign(state.results)
	assert_int(results.size()).is_equal(dispatches)
	return results


# GPU creation, uploads, dispatches, swaps, readbacks and cleanup stay together
func _run_on_render_thread(pressure: Image, dispatches: int, state: Dictionary) -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		_receive_result.call_deferred(state, [], "No RenderingDevice available.")
		return

	var size := pressure.get_size()
	var pressure_fbo := DoubleFBO.new(Vector2(size))
	var decay := PressureDecay.new(pressure_fbo)
	decay.value = DECAY
	var results: Array[Image] = []
	var message := ""
	# A sentinel ensures an unwritten output pixel fails even a zero-field test.
	var sentinel := Image.create(size.x, size.y, false, Image.FORMAT_RGBAH)
	sentinel.fill(Color(99.0, 99.0, 99.0, 0.0))

	var upload_error := rd.texture_update(
		pressure_fbo.get_texture_rd(), 0, pressure.get_data()
	)
	for index in range(dispatches):
		if upload_error == OK:
			upload_error = rd.texture_update(
				pressure_fbo.get_write_texture_rd(), 0, sentinel.get_data()
			)
		if upload_error != OK:
			message = "Texture upload failed: %s" % error_string(upload_error)
			break

		var previous_read := pressure_fbo.get_texture_rd()
		decay.process(0.0)
		if previous_read == pressure_fbo.get_texture_rd():
			message = "PressureDecay did not swap the pressure textures."
			break

		var bytes := rd.texture_get_data(pressure_fbo.get_texture_rd(), 0)
		if bytes.is_empty():
			message = "Pressure decay readback returned no data."
			break
		results.append(Image.create_from_data(
			size.x, size.y, false, Image.FORMAT_RGBAH, bytes
		))

	decay._compute_shader.release()
	decay._compute_shader._node = null
	pressure_fbo.release()
	_receive_result.call_deferred(state, results, message)


func _receive_result(state: Dictionary, results: Array, message: String) -> void:
	state.results = results
	state.error = message
	state.finished = true
