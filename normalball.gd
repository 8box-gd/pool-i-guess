extends RigidBody2D

@export var ball_ID = 0
@export var brake_limit = 50.0
@export var moving_damp = 0.5
@export var brake_damp = 3.0

var reset_point: Vector2 = Vector2.ZERO

signal sunk(ID)

func _ready():
	visible = true
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	reset_point = position
	contact_monitor = true
	max_contacts_reported = 2

func _process(delta):
	pass

func _physics_process(delta):
	#DETECT POCKETS
	if get_contact_count() > 0:
		var collisions = get_colliding_bodies()
		for i in len(collisions):
			if collisions[i].is_in_group("pocket"):
				set_collision_layer_value(1, false)
				set_collision_mask_value(1, false)
				visible = false
				emit_signal("sunk", ball_ID)
		
	if linear_velocity.length() > brake_limit:
		linear_damp = moving_damp
	else:
		linear_damp = brake_damp
	
	if visible == false:
		linear_damp = 10.0

func _on_root_reset_table():
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	rotation = 0
	global_transform.origin = reset_point
	visible = true
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
