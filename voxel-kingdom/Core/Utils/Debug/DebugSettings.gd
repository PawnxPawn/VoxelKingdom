#-###########################################
# Debug Settings Panel
#-###########################################

extends PanelContainer

@onready var labels_container: GridContainer = %LabelsContainer
@onready var button_container: GridContainer = %ButtonContainer
@onready var other_container: GridContainer = %OtherContainer
@onready var button: Button = $Button


func _ready() -> void:
	button.pressed.connect(func(): visible = false)
