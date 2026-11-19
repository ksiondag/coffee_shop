@abstract class_name GpuResources extends RefCounted

@abstract func uniform(binding: int) -> RDUniform
@abstract func get_size() -> Vector2
@abstract func free() -> void
