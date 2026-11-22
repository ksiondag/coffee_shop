extends GdUnitTestSuite

const GaussianSplat = preload("res://fluid/fluids2d/gaussian_splat.gd")
const TEST_SIZE := Vector2i(8, 8)
const TIMEOUT_MS := 5000
const TOLERANCE := 0.01


func test_zero_color_preserves_source() -> void:
	var results := await _run_splat(
		_ramp_image(TEST_SIZE), [_splat_args(Vector2(0.5, 0.5), Color(0, 0, 0, 0), 0.01)]
	)
	if results.is_empty():
		return
	_assert_color(results[0], func(x: int, y: int) -> Color: return _ramp(x, y))


func test_gaussian_is_added_to_existing_values() -> void:
	var point := Vector2(0.3, 0.6)
	var color := Color(2.0, -1.0, 0.5, 0.0)
	var radius := 0.05
	var results := await _run_splat(
		_ramp_image(TEST_SIZE), [_splat_args(point, color, radius)]
	)
	if results.is_empty():
		return
	_assert_color(results[0], func(x: int, y: int) -> Color:
		return _ramp(x, y) + _expected_splat(x, y, TEST_SIZE, point, color, radius, 1.0)
	)


func test_alpha_is_written_as_one() -> void:
	var source := _ramp_image(TEST_SIZE)
	source.fill(Color(0.0, 0.0, 0.0, 0.25))
	var results := await _run_splat(
		source, [_splat_args(Vector2(0.5, 0.5), Color(1, 1, 1, 5), 0.05)]
	)
	if results.is_empty():
		return
	for y in range(TEST_SIZE.y):
		for x in range(TEST_SIZE.x):
			assert_float(results[0].get_pixel(x, y).a).is_equal_approx(1.0, TOLERANCE)


func test_aspect_ratio_stretches_x_distance() -> void:
	var point := Vector2(0.5, 0.5)
	var color := Color(1.0, 0.0, 0.0, 0.0)
	var radius := 0.05
	var source := _ramp_image(TEST_SIZE)
	source.fill(Color(0.0, 0.0, 0.0, 1.0))
	var results := await _run_splat(source, [_splat_args(point, color, radius, 2.0)])
	if results.is_empty():
		return
	_assert_color(results[0], func(x: int, y: int) -> Color:
		var expected := _expected_splat(x, y, TEST_SIZE, point, color, radius, 2.0)
		expected.a = 1.0
		return expected
	)


func test_size_not_divisible_by_workgroup_size() -> void:
	var size := Vector2i(9, 11)
	var point := Vector2(0.7, 0.2)
	var color := Color(0.0, 3.0, 0.0, 0.0)
	var radius := 0.02
	var results := await _run_splat(_ramp_image(size), [_splat_args(point, color, radius)])
	if results.is_empty():
		return
	_assert_color(results[0], func(x: int, y: int) -> Color:
		return _ramp(x, y) + _expected_splat(x, y, size, point, color, radius, 1.0)
	)


func test_second_splat_accumulates_after_swap() -> void:
	var point := Vector2(0.5, 0.5)
	var color := Color(1.0, 0.0, 0.0, 0.0)
	var radius := 0.05
	var args := _splat_args(point, color, radius)
	var results := await _run_splat(_ramp_image(TEST_SIZE), [args, args])
	if results.size() != 2:
		return
	_assert_color(results[1], func(x: int, y: int) -> Color:
		var splat := _expected_splat(x, y, TEST_SIZE, point, color, radius, 1.0)
		return _ramp(x, y) + splat + splat
	)


func _splat_args(point: Vector2, color: Color, radius: float, aspect_ratio: float = 1.0) -> Dictionary:
	return {"point": point, "color": color, "radius": radius, "aspect_ratio": aspect_ratio}


func _expected_splat(
	x: int, y: int, size: Vector2i, point: Vector2, color: Color, radius: float, aspect_ratio: float
) -> Color:
	var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / Vector2(size)
	var p := uv - point
	p.x *= aspect_ratio
	var weight := exp(-p.dot(p) / radius)
	return Color(color.r * weight, color.g * weight, color.b * weight, 0.0)


# Distinct per pixel and channel; alpha is 1 because the shader writes alpha 1.
func _ramp(x: int, y: int) -> Color:
	return Color(0.1 * x, -0.1 * y, 0.25, 1.0)


func _ramp_image(size: Vector2i) -> Image:
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


func _run_splat(source: Image, splats: Array[Dictionary]) -> Array[Image]:
	var state := {"finished": false, "results": [], "error": ""}
	RenderingServer.call_on_render_thread(_run_on_render_thread.bind(source, splats, state))
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while not state.finished and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	assert_bool(state.finished).override_failure_message(
		"Timed out waiting for the Gaussian splat GPU test; check Godot's error output."
	).is_true()
	if not state.finished:
		return []
	assert_str(state.error).is_empty()
	if not state.error.is_empty():
		return []

	var results: Array[Image] = []
	results.assign(state.results)
	assert_int(results.size()).is_equal(splats.size())
	return results


# GPU creation, uploads, dispatches, swaps, readbacks and cleanup stay together
func _run_on_render_thread(source: Image, splats: Array[Dictionary], state: Dictionary) -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		_receive_result.call_deferred(state, [], "No RenderingDevice available.")
		return

	var size := source.get_size()
	var source_fbo := DoubleFBO.new(Vector2(size))
	var splat := GaussianSplat.new(source_fbo)
	var results: Array[Image] = []
	var message := ""
	# A sentinel ensures an unwritten output pixel fails even an unchanged-field test.
	var sentinel := Image.create(size.x, size.y, false, Image.FORMAT_RGBAH)
	sentinel.fill(Color(99.0, 99.0, 99.0, 0.0))

	var upload_error := rd.texture_update(source_fbo.get_texture_rd(), 0, source.get_data())
	for args in splats:
		if upload_error == OK:
			upload_error = rd.texture_update(source_fbo.get_write_texture_rd(), 0, sentinel.get_data())
		if upload_error != OK:
			message = "Texture upload failed: %s" % error_string(upload_error)
			break

		var previous_read := source_fbo.get_texture_rd()
		splat.process(args.point, args.color, args.radius, args.aspect_ratio)
		if previous_read == source_fbo.get_texture_rd():
			message = "GaussianSplat did not swap the source textures."
			break

		var bytes := rd.texture_get_data(source_fbo.get_texture_rd(), 0)
		if bytes.is_empty():
			message = "Gaussian splat readback returned no data."
			break
		results.append(Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBAH, bytes))

	splat.release()
	source_fbo.release()
	_receive_result.call_deferred(state, results, message)


func _receive_result(state: Dictionary, results: Array, message: String) -> void:
	state.results = results
	state.error = message
	state.finished = true
