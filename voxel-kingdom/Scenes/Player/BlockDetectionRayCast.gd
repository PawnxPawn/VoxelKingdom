#-###########################################
# Block RayCast
#-###########################################

class_name BlockRayCast
extends RayCast3D


#----------------
# Get Ray Hit
#----------------
func get_ray_hit() -> RayHit:
	var collider := get_collider()
	if collider is not Chunk:
		return null
	
	var point: Vector3 = get_collision_point()
	var normal: Vector3 = get_collision_normal()
	
	return RayHit.new(point, normal)


#-###############
# RayHit Class
#-###############
class RayHit:
	var hit_position: Vector3
	var hit_normal: Vector3
	
	func _init(position: Vector3, normal: Vector3) -> void:
		hit_position = position
		hit_normal = normal
