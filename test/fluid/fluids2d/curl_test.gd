extends GdUnitTestSuite

const Curl = preload("res://fluid/fluids2d/curl.gd")
const TEST_SIZE := Vector2i(8, 8)
const TIMEOUT_MS := 5000
const TOLERANCE := 0.001


func test_zero_velocity_makes_zero_curl() -> void:
	var velocity := _velocity_image(TEST_SIZE)
	velocity.fill(Color(0.0, 0.0, 0.0, 1.0))
	var results := await _run_curl([velocity])
	if results.is_empty():
		return
	_assert_output(results[0], func(_x: int, _y: int) -> float: return 0.0)


func test_constant_velocity_makes_zero_curl() -> void:
	var velocity := _velocity_image(TEST_SIZE)
	velocity.fill(Color(-3.0, 7.0, 0.0, 1.0))
	var results := await _run_curl([velocity])
	if results.is_empty():
		return
	_assert_output(results[0], func(_x: int, _y: int) -> float: return 0.0)


func test_vertical_velocity_increasing_across_x() -> void:
	var results := await _run_curl([_vertical_ramp(TEST_SIZE)])
	if results.is_empty():
		return
	_assert_output(results[0], func(x: int, _y: int) -> float:
		return 0.5 if x == 0 or x == TEST_SIZE.x - 1 else 1.0
	)


func test_horizontal_velocity_increasing_across_y_makes_negative_curl() -> void:
	var results := await _run_curl([_horizontal_ramp(TEST_SIZE)])
	if results.is_empty():
		return
	_assert_output(results[0], func(_x: int, y: int) -> float:
		return -0.5 if y == 0 or y == TEST_SIZE.y - 1 else -1.0
	)


func test_fixed_asymmetric_velocity_field() -> void:
	var velocity := _velocity_image(TEST_SIZE)
	velocity.fill(Color(0.0, 0.0, 0.0, 1.0))
	velocity.set_pixel(2, 3, Color(4.0, 0.0, 0.0, 1.0))
	velocity.set_pixel(5, 4, Color(0.0, -6.0, 0.0, 1.0))

	var expected := [
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, -2, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 2, 0, -3, 0, 3, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
	]
	var results := await _run_curl([velocity])
	if results.is_empty():
		return
	_assert_output(results[0], func(x: int, y: int) -> float:
		return float(expected[y][x])
	)


func test_size_not_divisible_by_workgroup_size() -> void:
	var size := Vector2i(9, 11)
	var results := await _run_curl([_vertical_ramp(size)])
	if results.is_empty():
		return
	_assert_output(results[0], func(x: int, _y: int) -> float:
		return 0.5 if x == 0 or x == size.x - 1 else 1.0
	)


func test_velocity_binding_follows_double_fbo_swap() -> void:
	var results := await _run_curl([
		_vertical_ramp(TEST_SIZE),
		_horizontal_ramp(TEST_SIZE),
	])
	if results.size() != 2:
		return
	_assert_output(results[0], func(x: int, _y: int) -> float:
		return 0.5 if x == 0 or x == TEST_SIZE.x - 1 else 1.0
	)
	_assert_output(results[1], func(_x: int, y: int) -> float:
		return -0.5 if y == 0 or y == TEST_SIZE.y - 1 else -1.0
	)


func _velocity_image(size: Vector2i) -> Image:
	return Image.create(size.x, size.y, false, Image.FORMAT_RGBAH)


func _vertical_ramp(size: Vector2i) -> Image:
	var velocity := _velocity_image(size)
	for y in range(size.y):
		for x in range(size.x):
			velocity.set_pixel(x, y, Color(0.0, float(x), 0.0, 1.0))
	return velocity


func _horizontal_ramp(size: Vector2i) -> Image:
	var velocity := _velocity_image(size)
	for y in range(size.y):
		for x in range(size.x):
			velocity.set_pixel(x, y, Color(float(y), 0.0, 0.0, 1.0))
	return velocity


func _assert_output(image: Image, expected: Callable) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var value: float = expected.call(x, y)
			var pixel := image.get_pixel(x, y)
			var location := "Pixel (%d, %d)" % [x, y]
			assert_float(pixel.r).override_failure_message(
				"%s: expected curl %s, got %s" % [location, value, pixel.r]
			).is_equal_approx(value, TOLERANCE)
			assert_float(pixel.g).is_equal_approx(0.0, TOLERANCE)
			assert_float(pixel.b).is_equal_approx(0.0, TOLERANCE)
			assert_float(pixel.a).override_failure_message(
				"%s: expected alpha 1, got %s" % [location, pixel.a]
			).is_equal_approx(1.0, TOLERANCE)


func _run_curl(velocities: Array[Image]) -> Array[Image]:
	var state := {"finished": false, "results": [], "error": ""}
	RenderingServer.call_on_render_thread(_run_on_render_thread.bind(velocities, state))
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while not state.finished and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	assert_bool(state.finished).override_failure_message(
		"Timed out waiting for the curl GPU test; check Godot's error output."
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
	var velocity_fbo := DoubleFBO.new(Vector2(size))
	var curl_fbo := FBO.new(Vector2(size))
	var curl := Curl.new(velocity_fbo, curl_fbo)
	var results: Array[Image] = []
	var message := ""

	var initial_curl := _velocity_image(size)
	# Initialize curl to value that should never get written to pixels
	initial_curl.fill(Color(99.0, 99.0, 99.0, 0.0))

	for index in range(velocities.size()):
		if index > 0:
			velocity_fbo.swap()

		var upload_error := rd.texture_update(
			velocity_fbo.get_texture_rd(), 0, velocities[index].get_data()
		)
		if upload_error == OK:
			upload_error = rd.texture_update(
				curl_fbo.get_texture_rd(), 0, initial_curl.get_data()
			)
		if upload_error != OK:
			message = "Texture upload failed: %s" % error_string(upload_error)
			break

		curl.process(0.0)
		var bytes := rd.texture_get_data(curl_fbo.get_texture_rd(), 0)
		if bytes.is_empty():
			message = "curl bytes unexpectedly empty"
			break
		results.append(Image.create_from_data(
			size.x, size.y, false, Image.FORMAT_RGBAH, bytes
		))

	curl._compute_shader.release()
	curl._compute_shader._node = null
	velocity_fbo.release()
	curl_fbo.release()

	_receive_result.call_deferred(state, results, message)


func _receive_result(state: Dictionary, results: Array, message: String) -> void:
	state.results = results
	state.error = message
	state.finished = true
