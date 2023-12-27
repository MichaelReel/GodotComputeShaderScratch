extends Node

@export_group("Requirements")
@export_file("*.glsl") var _compute_shader: String
@export var _renderer: TextureRect

const _GLSL_LOCAL_SIZE: Vector3i = Vector3i(8, 8, 1)  # Would be nice to extract from the glsl

var _rd: RenderingDevice
var _shader: RID
var _buffer: RID
var _input_texure: RID
var _uniform_set : RID
var _pipeline: RID

var _image_size: Vector2i
var _group_size: Vector3i

var _bindings: Array[RDUniform] = []

@onready var _rand := RandomNumberGenerator.new()

func _set_image_size(image_size: Vector2i) -> void:
	_image_size = image_size
	_group_size = Vector3i(
		_image_size.x / _GLSL_LOCAL_SIZE.x,
		_image_size.y / _GLSL_LOCAL_SIZE.y,
		1,
	)

func _create_local_rendering_device() -> void:
	_rd = RenderingServer.create_local_rendering_device()
	if not _rd:
		set_process(false)
		printerr("Compute shaders are not available")

func _load_glsl_shader() -> void:
	var shader_file: RDShaderFile = load(_compute_shader) as RDShaderFile
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	_shader = _rd.shader_create_from_spirv(shader_spirv)

func _get_distributed_vectors() -> PackedInt32Array:
	var vectors_as_ints := PackedInt32Array()
	# Make distributed randomly
	for gy in _group_size.y:
		for gx in _group_size.x:
			var point_x: int = gx * _GLSL_LOCAL_SIZE.x + _rand.randi_range(0, _GLSL_LOCAL_SIZE.x - 1)
			var point_y: int = gy * _GLSL_LOCAL_SIZE.y + _rand.randi_range(0, _GLSL_LOCAL_SIZE.y - 1)
			vectors_as_ints.append_array([point_x, point_y])
			
	return vectors_as_ints

func _prepare_float_array_input_data() -> void:
	# Prepare our data. We use floats in the shader, so we need 32 bit.
	var input := _get_distributed_vectors()
	var input_bytes: PackedByteArray = input.to_byte_array()
	
	# Create a storage buffer that can hold our float values.
	# Each float has 4 bytes (32 bit) so 10 x 4 = 40 bytes
	_buffer = _rd.storage_buffer_create(input_bytes.size(), input_bytes)
	
	# Create a uniform to assign the buffer to the rendering device
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0 # this needs to match the "binding" in our shader file
	uniform.add_id(_buffer)
	_bindings.append(uniform)

func _create_texture_and_uniform(image: Image, format: RDTextureFormat, binding: int) -> RID:
	var view := RDTextureView.new()
	var data: PackedByteArray = image.get_data()
	var texture_id: RID = _rd.texture_create(format, view, [data])
	
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(texture_id)
	
	_bindings.append(uniform)
	return texture_id

func _default_texture_format(size: Vector2i) -> RDTextureFormat:
	var format := RDTextureFormat.new()
	format.width = size.x
	format.height = size.y
	format.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	return format

func _prepare_texture_uniforms() -> void:
	var input_image: Image = _renderer.texture.get_image()
	var input_format: RDTextureFormat = _default_texture_format(_image_size)
	_input_texure = _create_texture_and_uniform(input_image, input_format, 1)

func _apply_uniforms() -> void:
	_uniform_set = _rd.uniform_set_create(_bindings, _shader, 0)

func _create_compute_pipeline() -> void:
	# Create a compute pipeline
	_pipeline = _rd.compute_pipeline_create(_shader)
	var compute_list: int = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(compute_list, _pipeline)
	_rd.compute_list_bind_uniform_set(compute_list, _uniform_set, 0)
	_rd.compute_list_dispatch(compute_list, _group_size.x, _group_size.y, _group_size.z)
	_rd.compute_list_end()

func _submit_to_gpu_and_sync() -> void:
	_rd.submit()
	_rd.sync()

func _extract_output_data() -> void:
	# Read back the data from the buffer
	
	var image_bytes : PackedByteArray = _rd.texture_get_data(_input_texure, 0)
	var output_image : Image = _renderer.texture.get_image()
	output_image.set_data(_image_size.x, _image_size.y, false, Image.FORMAT_L8, image_bytes)
	_renderer.texture = ImageTexture.create_from_image(output_image)

#func _cleanup_gpu() -> void:
	#if not _rd: return
	#_rd.free_rid(_input_texure)
	#_rd.free_rid(_output_texure)
	#_rd.free_rid(_uniform_set)
	#_rd.free_rid(_pipeline)
	#_rd.free_rid(_buffer)
	#_rd.free_rid(_shader)
	#_rd.free()
	#_rd = null

func dispatch() -> void:
	_set_image_size(_renderer.texture.get_image().get_size())
	_create_local_rendering_device()
	_load_glsl_shader()
	_prepare_float_array_input_data()
	_prepare_texture_uniforms()
	_apply_uniforms()
	_create_compute_pipeline()
	_submit_to_gpu_and_sync()
	_extract_output_data()
	#_cleanup_gpu()
