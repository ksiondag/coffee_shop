extends GdUnitTestSuite

const Advection = preload("res://fluid/fluids2d/advection.gd")
const TEST_SIZE := Vector2i(8, 8)
const TIMEOUT_MS := 5000
const TOLERANCE := 0.02


func test_zero_velocity_and_dissipation_preserves_source() -> void:
	var results := await _run_advection(
		_velocity_image(TEST_SIZE, Vector2.ZERO), _source_ramp(TEST_SIZE), 0.5, 0.0
	)
	if results.is_empty():
		return
	_assert_color(results[0], func(x: int, y: int) -> Color: return _ramp(x, y))


func test_zero_delta_neither_moves_nor_decays() -> void:
	var results := await _run_advection(
		_velocity_image(TEST_SIZE, Vector2(3.0, 2.0)), _source_ramp(TEST_SIZE), 0.0, 1.0
	)
	if results.is_empty():
		return
	_assert_color(results[0], func(x: int, y: int) -> Color: return _ramp(x, y))


func test_dissipation_divides_color_but_not_alpha() -> void:
	var results := await _run_advection(
		_velocity_image(TEST_SIZE, Vector2.ZERO), _source_ramp(TEST_SIZE), 0.5, 0.5
	)
	if results.is_empty():
		return
	_assert_color(results[0], func(x: int, y: int) -> Color:
		var color := _ramp(x, y)
		return Color(color.r / 1.25, color.g / 1.25, color.b / 1.25, color.a)
	)


func test_positive_x_velocity_moves_source_in_positive_x() -> void:
	var results := await _run_advection(
		_velocity_image(TEST_SIZE, Vector2(2.0, 0.0)), _source_ramp(TEST_SIZE), 1.0, 0.0
	)
	if results.is_empty():
		return
	_assert_color(results[0], func(x: int, y: int) -> Color: return _ramp(maxi(x - 2, 0), y))


func test_negative_y_velocity_moves_source_in_negative_y() -> void:
	var last := TEST_SIZE.y - 1
	var results := await _run_advection(
		_velocity_image(TEST_SIZE, Vector2(0.0, -3.0)), _source_ramp(TEST_SIZE), 1.0, 0.0
	)
	if results.is_empty():
		return
	_assert_color(results[0], func(x: int, y: int) -> Color: return _ramp(x, mini(y + 3, last)))


func test_half_texel_shift_interpolates_neighbours() -> void:
	var results := await _run_advection(
		_velocity_image(TEST_SIZE, Vector2(0.5, 0.0)), _source_ramp(TEST_SIZE), 1.0, 0.0
	)
	if results.is_empty():
		return
	_assert_color(results[0], func(x: int, y: int) -> Color:
		var color := _ramp(x, y)
		color.r = 0.0 if x == 0 else x - 0.5
		return color
	)


func test_constant_velocity_advecting_itself_is_unchanged() -> void:
	var velocity := Vector2(1.5, -0.5)
	var results := await _run_advection(_velocity_image(TEST_SIZE, velocity), null, 1.0, 0.0)
	if results.is_empty():
		return
	_assert_color(results[0], func(_x: int, _y: int) -> Color:
		return Color(velocity.x, velocity.y, 0.0, 1.0)
	)


func test_size_not_divisible_by_workgroup_size() -> void:
	var size := Vector2i(9, 11)
	var results := await _run_advection(
		_velocity_image(size, Vector2(2.0, 0.0)), _source_ramp(size), 1.0, 0.0
	)
	if results.is_empty():
		return
	_assert_color(results[0], func(x: int, y: int) -> Color: return _ramp(maxi(x - 2, 0), y))


func test_source_resolution_can_differ_from_velocity() -> void:
	var source_size := Vector2i(16, 16)
	var results := await _run_advection(
		_velocity_image(TEST_SIZE, Vector2(2.0, 0.0)), _source_ramp(source_size), 1.0, 0.0
	)
	if results.is_empty():
		return
	_assert_color(results[0], func(x: int, y: int) -> Color: return _ramp(maxi(x - 4, 0), y))


func test_second_dispatch_reads_first_result_after_swap() -> void:
	var results := await _run_advection(
		_velocity_image(TEST_SIZE, Vector2(2.0, 0.0)), _source_ramp(TEST_SIZE), 1.0, 0.0, 2
	)
	if results.size() != 2:
		return
	_assert_color(results[0], func(x: int, y: int) -> Color: return _ramp(maxi(x - 2, 0), y))
	_assert_color(results[1], func(x: int, y: int) -> Color: return _ramp(maxi(x - 4, 0), y))


func _velocity_image(size: Vector2i, velocity: Vector2) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBAH)
	image.fill(Color(velocity.x, velocity.y, 0.0, 1.0))
	return image


# Distinct per pixel and per channel, so a wrong pixel, axis or channel is visible
func _ramp(x: int, y: int) -> Color:
	return Color(float(x), float(y), 0.5, 1.0)


func _source_ramp(size: Vector2i) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBAH)
	for y in range(size.y):
		for x in range(size.x):
			image.set_pixel(x, y, _ramp(x, y))
	return image


func _assert_color(image: Image, expected: Callable) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var value: Color = expected.call(x, y)
			var pixel := image.get_pixel(x, y)
			var location := "Pixel (%d, %d)" % [x, y]
			assert_float(pixel.r).override_failure_message(
				"%s: expected r %s, got %s" % [location, value.r, pixel.r]
			).is_equal_approx(value.r, TOLERANCE)
			assert_float(pixel.g).override_failure_message(
				"%s: expected g %s, got %s" % [location, value.g, pixel.g]
			).is_equal_approx(value.g, TOLERANCE)
			assert_float(pixel.b).override_failure_message(
				"%s: expected b %s, got %s" % [location, value.b, pixel.b]
			).is_equal_approx(value.b, TOLERANCE)
			assert_float(pixel.a).override_failure_message(
				"%s: expected a %s, got %s" % [location, value.a, pixel.a]
			).is_equal_approx(value.a, TOLERANCE)


# source == null advects velocity by itself
func _run_advection(
	velocity: Image, source: Image, delta: float, dissipation: float, dispatches: int = 1
) -> Array[Image]:
	var state := {"finished": false, "results": [], "error": ""}
	RenderingServer.call_on_render_thread(
		_run_on_render_thread.bind(velocity, source, delta, dissipation, dispatches, state)
	)
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while not state.finished and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	assert_bool(state.finished).override_failure_message(
		"Timed out waiting for the advection GPU test; check Godot's error output."
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


# GPU creation, uploads, dispatches, swaps, readbacks and cleanup stay together.
func _run_on_render_thread(
	velocity: Image, source: Image, delta: float, dissipation: float,
	dispatches: int, state: Dictionary
) -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		_receive_result.call_deferred(state, [], "No RenderingDevice available.")
		return

	var velocity_fbo := DoubleFBO.new(Vector2(velocity.get_size()))

	# Pick the field being advected: velocity itself, or a separate DoubleFBO
	# (possibly a different size) standing in for dye
	var target_size := velocity.get_size() if source == null else source.get_size()
	var source_fbo: DoubleFBO = null
	var target := velocity_fbo
	if source != null:
		source_fbo = DoubleFBO.new(Vector2(target_size))
		target = source_fbo

	var advection := Advection.new(velocity_fbo, target, dissipation)
	var results: Array[Image] = []
	var message := ""

	var sentinel := Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBAH)
	sentinel.fill(Color(99.0, 99.0, 99.0, 0.0))

	var upload_error := rd.texture_update(
		velocity_fbo.get_texture_rd(), 0, velocity.get_data()
	)
	if upload_error == OK and source != null:
		upload_error = rd.texture_update(target.get_texture_rd(), 0, source.get_data())

	for index in range(dispatches):
		if upload_error == OK:
			upload_error = rd.texture_update(target.get_write_texture_rd(), 0, sentinel.get_data())
		if upload_error != OK:
			message = "Texture upload failed: %s" % error_string(upload_error)
			break

		var previous_read := target.get_texture_rd()
		advection.process(delta)
		if previous_read == target.get_texture_rd():
			message = "Advection did not swap the source textures."
			break

		var bytes := rd.texture_get_data(target.get_texture_rd(), 0)
		if bytes.is_empty():
			message = "Advection readback returned no data."
			break
		results.append(Image.create_from_data(
			target_size.x, target_size.y, false, Image.FORMAT_RGBAH, bytes
		))

	advection.release()
	if source_fbo != null:
		source_fbo.release()
	velocity_fbo.release()
	_receive_result.call_deferred(state, results, message)


func _receive_result(state: Dictionary, results: Array, message: String) -> void:
	state.results = results
	state.error = message
	state.finished = true
