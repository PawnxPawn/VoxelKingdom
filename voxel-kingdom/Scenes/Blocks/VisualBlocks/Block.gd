#-###########################################
# Block Component
#-###########################################

extends Node3D

@export var block_color: Color = Color.DARK_GREEN
@onready var block: CSGBox3D = $BlockMesh
