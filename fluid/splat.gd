extends Node


const ComputeShader = preload("res://gpu/compute_shader.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")
const FluidFields = preload("res://fluid/fluid_fields.gd")
const GaussianSplat = preload("res://fluid/fluids2d/gaussian_splat.gd")

@export var fluid_fields: FluidFields

@export var output: Texture2DRD
@export var color: Color

@export var radius: float

var dye: DoubleFBO
var dye_splat: GaussianSplat

var velocity: DoubleFBO
var velocity_splat: GaussianSplat

var texture_size: Vector2i


func _input(event) -> void:
	if event.is_action_pressed("click"):
		if dye_splat != null:
			dye_splat.process(
				Vector2(event.position.x / dye.get_size().x, event.position.y / dye.get_size().y),
				color,
				radius / 10.0,
				dye.get_size().x / dye.get_size().y
			)
		if velocity_splat != null:
			velocity_splat.process(
				Vector2(event.position.x / velocity.get_size().x, event.position.y / velocity.get_size().y),
				Color(
					0,
					600,
					0,
					0,
				),
				radius,
				velocity.get_size().x / velocity.get_size().y
			)


func _enter_tree() -> void:
	pass


func _exit_tree() -> void:
	if dye_splat != null:
		dye_splat.release()
	dye_splat = null
	if velocity_splat != null:
		velocity_splat.release()
	velocity_splat = null


func _process(delta: float) -> void:
	# Only send splat on click
	pass


func _on_view_resized(_size: Vector2) -> void:
	if dye == null && fluid_fields.initialized:
		dye = fluid_fields.dye
		dye.set_texture(output)
		dye_splat = GaussianSplat.new(dye)
	if velocity == null && fluid_fields.initialized:
		velocity = fluid_fields.velocity
		velocity_splat = GaussianSplat.new(velocity)
