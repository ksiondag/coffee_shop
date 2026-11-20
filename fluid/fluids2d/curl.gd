extends RefCounted


const SHADER_PATH := "res://fluid/shaders/curl.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")
const FBO = preload("res://gpu/fbo.gd")
const FluidFields = preload("res://fluid/fluid_fields.gd")

@export var fluid_fields: FluidFields

@export var output: Texture2DRD
@export var color: Color

@export var radius: float

var _fbo: FBO
var _compute_shader: ComputeShader


func _init(fbo: FBO) -> void:
	# TODO: Computer Shader assumes too much. curl.gd needs to know about
	# shaders expected uniform sets and set that up in the GPU before running
	# shader
	# Should these classes extend GpuResources?
	# Or should ComputeShader become an abstract class?
	# That makes a lot of sense to me, actually
	_fbo = fbo
	_compute_shader = ComputeShader.new(_fbo, SHADER_PATH)


func process(_delta: float) -> void:
	pass


# RenderingThread functions
