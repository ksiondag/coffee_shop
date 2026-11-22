extends GdUnitTestSuite

const Divergence = preload("res://fluid/fluids2d/divergence.gd")
const TEST_SIZE := Vector2i(8, 8)
const TIMEOUT_MS := 5000
const TOLERANCE := 0.001


func test_zero_velocity_makes_zero_divergence() -> void:
	var velocity := _velocity_image(TEST_SIZE)
	velocity.fill(Color(0.0, 0.0, 0.0, 1.0))
	var results := await _run_divergence([velocity])
	if results.is_empty():
		return
	_assert_output(results[0], func(_x: int, _y: int) -> float: return 0.0)


func test_constant_velocity_reflects_at_walls() -> void:
	# Interior is divergence-free; each wall reflects the flow pointing into it.
	var c := 3.0
	var d := -2.0
	var velocity := _velocity_image(TEST_SIZE)
	velocity.fill(Color(c, d, 0.0, 1.0))
	var results := await _run_divergence([velocity])
	if results.is_empty():
		return
	_assert_output(results[0], func(x: int, y: int) -> float:
		var value := 0.0
		if x == 0:
			value += c
		if x == TEST_SIZE.x - 1:
			value -= c
		if y == 0:
			value += d
		if y == TEST_SIZE.y - 1:
			value -= d
		return value
	)


func test_horizontal_velocity_increasing_across_x() -> void:
	var results := await _run_divergence([_horizontal_ramp(TEST_SIZE)])
	if results.is_empty():
		return
	_assert_output(results[0], func(x: int, _y: int) -> float:
		return _ramp_divergence(x, TEST_SIZE.x)
	)


func test_vertical_velocity_increasing_across_y() -> void:
	var results := await _run_divergence([_vertical_ramp(TEST_SIZE)])
	if results.is_empty():
		return
	_assert_output(results[0], func(_x: int, y: int) -> float:
		return _ramp_divergence(y, TEST_SIZE.y)
	)


func test_fixed_asymmetric_velocity_field() -> void:
	var velocity := _velocity_image(TEST_SIZE)
	velocity.fill(Color(0.0, 0.0, 0.0, 1.0))
	velocity.set_pixel(2, 3, Color(4.0, 0.0, 0.0, 1.0))
	velocity.set_pixel(5, 4, Color(0.0, -6.0, 0.0, 1.0))

	var expected := [
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 2, 0, -2, 0, -3, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 3, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
	]
	var results := await _run_divergence([velocity])
	if results.is_empty():
		return
	_assert_output(results[0], func(x: int, y: int) -> float:
		return float(expected[y][x])
	)


func test_size_not_divisible_by_workgroup_size() -> void:
	var size := Vector2i(9, 11)
	var results := await _run_divergence([_horizontal_ramp(size)])
	if results.is_empty():
		return
	_assert_output(results[0], func(x: int, _y: int) -> float:
		return _ramp_divergence(x, size.x)
	)


func test_velocity_binding_follows_double_fbo_swap() -> void:
	var results := await _run_divergence([
		_horizontal_ramp(TEST_SIZE),
		_vertical_ramp(TEST_SIZE),
	])
	if results.size() != 2:
		return
	_assert_output(results[0], func(x: int, _y: int) -> float:
		return _ramp_divergence(x, TEST_SIZE.x)
	)
	_assert_output(results[1], func(_x: int, y: int) -> float:
		return _ramp_divergence(y, TEST_SIZE.y)
	)


func _velocity_image(size: Vector2i) -> Image:
	return Image.create(size.x, size.y, false, Image.FORMAT_RGBAH)


# vx = x
func _horizontal_ramp(size: Vector2i) -> Image:
	var velocity := _velocity_image(size)
	for y in range(size.y):
		for x in range(size.x):
			velocity.set_pixel(x, y, Color(float(x), 0.0, 0.0, 1.0))
	return velocity


# vy = y
func _vertical_ramp(size: Vector2i) -> Image:
	var velocity := _velocity_image(size)
	for y in range(size.y):
		for x in range(size.x):
			velocity.set_pixel(x, y, Color(0.0, float(y), 0.0, 1.0))
	return velocity


func _ramp_divergence(coordinate: int, length: int) -> float:
	if coordinate == 0:
		return 0.5
	if coordinate == length - 1:
		return 0.5 * (-(length - 1) - (length - 2))
	return 1.0


func _assert_output(image: Image, expected: Callable) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var value: float = expected.call(x, y)
			var pixel := image.get_pixel(x, y)
			var location := "Pixel (%d, %d)" % [x, y]
			assert_float(pixel.r).override_failure_message(
				"%s: expected divergence %s, got %s" % [location, value, pixel.r]
			).is_equal_approx(value, TOLERANCE)
			assert_float(pixel.g).is_equal_approx(0.0, TOLERANCE)
			assert_float(pixel.b).is_equal_approx(0.0, TOLERANCE)
			assert_float(pixel.a).override_failure_message(
				"%s: expected alpha 1, got %s" % [location, pixel.a]
			).is_equal_approx(1.0, TOLERANCE)


func _run_divergence(velocities: Array[Image]) -> Array[Image]:
	var state := {"finished": false, "results": [], "error": ""}
	RenderingServer.call_on_render_thread(_run_on_render_thread.bind(velocities, state))
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while not state.finished and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	assert_bool(state.finished).override_failure_message(
		"Timed out waiting for the divergence GPU test; check Godot's error output."
	).is_true()
	if not state.finished:
		return []

	assert_str(state.error).is_empty()
	if not state.error.is_empty():
		return []

	var results: Array[Image] = []
	results.assign(state.results)
	assert_int(results.size()).is_equal(velocities.size())
	return results


# GPU creation, uploads, dispatches, readbacks and cleanup happen here
func _run_on_render_thread(velocities: Array[Image], state: Dictionary) -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		_receive_result.call_deferred(state, [], "No RenderingDevice available.")
		return

	var size := velocities[0].get_size()
	var fields := FluidFields.new()
	fields.initialize(Vector2(size))
	var divergence := Divergence.new(fields)
	var results: Array[Image] = []
	var message := ""

	var initial_divergence := _velocity_image(size)
	initial_divergence.fill(Color(99.0, 99.0, 99.0, 0.0))

	for index in range(velocities.size()):
		if index > 0:
			fields.velocity.swap()

		var upload_error := rd.texture_update(
			fields.velocity.get_texture_rd(), 0, velocities[index].get_data()
		)
		if upload_error == OK:
			upload_error = rd.texture_update(
				fields.divergence.get_texture_rd(), 0, initial_divergence.get_data()
			)
		if upload_error != OK:
			message = "Texture upload failed: %s" % error_string(upload_error)
			break

		divergence.process(0.0)
		var bytes := rd.texture_get_data(fields.divergence.get_texture_rd(), 0)
		if bytes.is_empty():
			message = "Divergence readback returned no data."
			break
		results.append(Image.create_from_data(
			size.x, size.y, false, Image.FORMAT_RGBAH, bytes
		))

	divergence._compute_shader.release()
	divergence._compute_shader._node = null
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
