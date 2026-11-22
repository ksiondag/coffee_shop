extends GdUnitTestSuite

const Vorticity = preload("res://fluid/fluids2d/vorticity.gd")
const TEST_SIZE := Vector2i(8, 8)
const TIMEOUT_MS := 5000
const TOLERANCE := 0.005
# Set explicitly on the pass so the tests don't depend on the config default.
# Large enough that the force stands well clear of the half-float tolerance.
const STRENGTH := 30.0
const NORMALIZATION_EPSILON := 0.0001


func test_zero_curl_preserves_velocity() -> void:
	var initial := Vector2(-2.0, 3.0)
	var results := await _run_vorticity(
		_constant_image(TEST_SIZE, Color(initial.x, initial.y, 0.0, 1.0)),
		[_constant_image(TEST_SIZE, Color(0.0, 0.0, 0.0, 1.0))], 0.01
	)
	if results.is_empty():
		return
	_assert_velocity(results[0], func(_x: int, _y: int) -> Vector2: return initial)


func test_constant_nonzero_curl_has_no_confinement_force() -> void:
	var initial := Vector2(2.0, -3.0)
	var results := await _run_vorticity(
		_constant_image(TEST_SIZE, Color(initial.x, initial.y, 0.0, 1.0)),
		[_constant_image(TEST_SIZE, Color(-5.0, 0.0, 0.0, 1.0))], 0.01
	)
	if results.is_empty():
		return
	_assert_velocity(results[0], func(_x: int, _y: int) -> Vector2: return initial)


func test_zero_delta_preserves_velocity() -> void:
	var initial := Vector2(-2.0, 3.0)
	var results := await _run_vorticity(
		_constant_image(TEST_SIZE, Color(initial.x, initial.y, 0.0, 1.0)),
		[_curl_ramp(TEST_SIZE, true)], 0.0
	)
	if results.is_empty():
		return
	_assert_velocity(results[0], func(_x: int, _y: int) -> Vector2: return initial)


func test_curl_magnitude_increasing_across_x_pushes_negative_y() -> void:
	var results := await _run_vorticity(
		_constant_image(TEST_SIZE, Color(0.0, 0.0, 0.0, 1.0)),
		[_curl_ramp(TEST_SIZE, true)], 0.01
	)
	if results.is_empty():
		return
	_assert_velocity(results[0], func(x: int, _y: int) -> Vector2:
		return Vector2(0.0, -_ramp_impulse(x, TEST_SIZE.x, 0.01))
	)


func test_negative_curl_reverses_force() -> void:
	var results := await _run_vorticity(
		_constant_image(TEST_SIZE, Color(0.0, 0.0, 0.0, 1.0)),
		[_curl_ramp(TEST_SIZE, true, -1.0)], 0.01
	)
	if results.is_empty():
		return
	_assert_velocity(results[0], func(x: int, _y: int) -> Vector2:
		return Vector2(0.0, _ramp_impulse(x, TEST_SIZE.x, 0.01))
	)


func test_y_gradient_with_uneven_texture_dimensions() -> void:
	var size := Vector2i(9, 11)
	var results := await _run_vorticity(
		_constant_image(size, Color(0.0, 0.0, 0.0, 1.0)),
		[_curl_ramp(size, false)], 0.01
	)
	if results.is_empty():
		return
	_assert_velocity(results[0], func(_x: int, y: int) -> Vector2:
		return Vector2(_ramp_impulse(y, size.y, 0.01), 0.0)
	)


func test_force_scales_with_delta() -> void:
	var results := await _run_vorticity(
		_constant_image(TEST_SIZE, Color(0.0, 0.0, 0.0, 1.0)),
		[_curl_ramp(TEST_SIZE, true)], 0.02
	)
	if results.is_empty():
		return
	_assert_velocity(results[0], func(x: int, _y: int) -> Vector2:
		return Vector2(0.0, -_ramp_impulse(x, TEST_SIZE.x, 0.02))
	)


func test_consecutive_passes_follow_velocity_swaps() -> void:
	var initial := Vector2(2.0, -3.0)
	var results := await _run_vorticity(
		_constant_image(TEST_SIZE, Color(initial.x, initial.y, 0.0, 1.0)),
		[_curl_ramp(TEST_SIZE, true), _curl_ramp(TEST_SIZE, false)], 0.01
	)
	if results.size() != 2:
		return
	_assert_velocity(results[0], func(x: int, _y: int) -> Vector2:
		return initial + Vector2(0.0, -_ramp_impulse(x, TEST_SIZE.x, 0.01))
	)
	_assert_velocity(results[1], func(x: int, y: int) -> Vector2:
		return initial + Vector2(
			_ramp_impulse(y, TEST_SIZE.y, 0.01),
			-_ramp_impulse(x, TEST_SIZE.x, 0.01)
		)
	)


func _constant_image(size: Vector2i, color: Color) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBAH)
	image.fill(color)
	return image


func _curl_ramp(size: Vector2i, across_x: bool, sign_value: float = 1.0) -> Image:
	var image := _constant_image(size, Color(0.0, 0.0, 0.0, 1.0))
	for y in range(size.y):
		for x in range(size.x):
			var coordinate := x if across_x else y
			image.set_pixel(x, y, Color(sign_value * (coordinate + 1), 0.0, 0.0, 1.0))
	return image


func _ramp_impulse(coordinate: int, length: int, delta: float) -> float:
	var gradient := 0.5 if coordinate == 0 or coordinate == length - 1 else 1.0
	return STRENGTH * (coordinate + 1) * delta * gradient / (gradient + NORMALIZATION_EPSILON)


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
			assert_float(pixel.a).is_equal_approx(1.0, TOLERANCE)


func _run_vorticity(velocity: Image, curls: Array[Image], delta: float) -> Array[Image]:
	var state := {"finished": false, "results": [], "error": ""}
	RenderingServer.call_on_render_thread(
		_run_on_render_thread.bind(velocity, curls, delta, state)
	)
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while not state.finished and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	assert_bool(state.finished).override_failure_message(
		"Timed out waiting for the vorticity GPU test; check Godot's error output."
	).is_true()
	if not state.finished:
		return []
	assert_str(state.error).is_empty()
	if not state.error.is_empty():
		return []

	var results: Array[Image] = []
	results.assign(state.results)
	assert_int(results.size()).is_equal(curls.size())
	return results


# GPU creation, uploads, dispatches, swaps, readbacks and cleanup stay together
func _run_on_render_thread(velocity: Image, curls: Array[Image], delta: float, state: Dictionary) -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		_receive_result.call_deferred(state, [], "No RenderingDevice available.")
		return

	var size := velocity.get_size()
	var velocity_fbo := DoubleFBO.new(Vector2(size))
	var curl_fbo := FBO.new(Vector2(size))
	var vorticity := Vorticity.new(velocity_fbo, curl_fbo)
	vorticity.strength = STRENGTH
	var results: Array[Image] = []
	var message := ""
	var sentinel := _constant_image(size, Color(99.0, 99.0, 99.0, 0.0))
	var upload_error := rd.texture_update(
		velocity_fbo.get_texture_rd(), 0, velocity.get_data()
	)

	for curl_image in curls:
		if upload_error == OK:
			upload_error = rd.texture_update(curl_fbo.get_texture_rd(), 0, curl_image.get_data())
		if upload_error == OK:
			upload_error = rd.texture_update(
				velocity_fbo.get_write_texture_rd(), 0, sentinel.get_data()
			)
		if upload_error != OK:
			message = "Texture upload failed: %s" % error_string(upload_error)
			break

		var previous_read := velocity_fbo.get_texture_rd()
		vorticity.process(delta)
		if previous_read == velocity_fbo.get_texture_rd():
			message = "Vorticity did not swap the velocity textures"
			break

		var bytes := rd.texture_get_data(velocity_fbo.get_texture_rd(), 0)
		if bytes.is_empty():
			message = "Vorticity readback returned no data"
			break
		results.append(Image.create_from_data(
			size.x, size.y, false, Image.FORMAT_RGBAH, bytes
		))

	vorticity.release()
	velocity_fbo.release()
	curl_fbo.release()
	_receive_result.call_deferred(state, results, message)


func _receive_result(state: Dictionary, results: Array, message: String) -> void:
	state.results = results
	state.error = message
	state.finished = true
