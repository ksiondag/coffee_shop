extends GdUnitTestSuite

const Curl = preload("res://fluid/fluids2d/curl.gd")
const TEST_SIZE := Vector2i(8, 8)

var _result: Image
var _finished := false
var _error := ""


func test_vertical_velocity_increasing_across_x() -> void:
	_result = null
	_finished = false
	_error = ""

	RenderingServer.call_on_render_thread(_run_curl_test)

	# The render thread delivers the result back via a deferred call.
	while not _finished:
		await get_tree().process_frame

	assert_str(_error).is_empty()
	if _result == null:
		return

	for y in range(TEST_SIZE.y):
		for x in range(TEST_SIZE.x):
			# Clamping halves the derivative at the left/right edges.
			var expected := 1.0
			if x == 0 or x == TEST_SIZE.x - 1:
				expected = 0.5

			var pixel := _result.get_pixel(x, y)
			assert_float(pixel.r).is_equal_approx(expected, 0.001)
			assert_float(pixel.a).is_equal_approx(1.0, 0.001)


# Runs entirely on the render thread.
func _run_curl_test() -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		_receive_result.call_deferred(null, "No RenderingDevice available.")
		return

	var fields := FluidFields.new()
	fields.initialize(Vector2(TEST_SIZE))

	var velocity := Image.create(
		TEST_SIZE.x, TEST_SIZE.y, false, Image.FORMAT_RGBAH
	)
	for y in range(TEST_SIZE.y):
		for x in range(TEST_SIZE.x):
			velocity.set_pixel(x, y, Color(0.0, float(x), 0.0, 1.0))

	# A sentinel ensures an unwritten output pixel fails the test.
	var initial_curl := Image.create(
		TEST_SIZE.x, TEST_SIZE.y, false, Image.FORMAT_RGBAH
	)
	initial_curl.fill(Color(99.0, 0.0, 0.0, 0.0))

	var upload_error := rd.texture_update(
		fields.velocity.get_texture_rd(), 0, velocity.get_data()
	)
	if upload_error == OK:
		upload_error = rd.texture_update(
			fields.curl.get_texture_rd(), 0, initial_curl.get_data()
		)

	if upload_error != OK:
		_release_fields(fields)
		_receive_result.call_deferred(
			null, "Texture upload failed: %s" % error_string(upload_error)
		)
		return

	var curl := Curl.new(fields)
	curl.process(0.0)

	# Blocking readback waits for the GPU results.
	var bytes := rd.texture_get_data(fields.curl.get_texture_rd(), 0)
	var result: Image
	var message := ""

	if bytes.is_empty():
		message = "Curl readback returned no data."
	else:
		result = Image.create_from_data(
			TEST_SIZE.x, TEST_SIZE.y, false, Image.FORMAT_RGBAH, bytes
		)

	# Cleanup using your current helper's internal shader reference.
	curl._compute_shader.release()
	# Break the reference cycle between Curl and its CurlShader.
	curl._compute_shader._node = null
	_release_fields(fields)

	_receive_result.call_deferred(result, message)


func _release_fields(fields: FluidFields) -> void:
	fields.dye.release()
	fields.velocity.release()
	fields.divergence.release()
	fields.curl.release()
	fields.pressure.release()


# Deferred calls run on the main thread.
func _receive_result(result: Image, message: String) -> void:
	_result = result
	_error = message
	_finished = true
