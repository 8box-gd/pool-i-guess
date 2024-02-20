extends Node2D


@export var cue_force = 1000.0
@export var brake_limit = 50.0
@export var next_shot_limit = 10.0
@export var max_mouse_dist = 100.0
@export var moving_damp = 0.5
@export var brake_damp = 3.0

@onready var cueball = $"cueball root/cueball"
@onready var guidepoint = $"cueball root/guidepoint"
@onready var guideline = $"cueball root/guideline"
@onready var debug_label = $DebugLabel
@onready var shot_wait_timer = $ShotWaitTimer

var cueball_slowed = true
var reset_point: Vector2 = Vector2.ZERO
var stroke_number = 0
var scratch_count = 0
var shot_allowed = true
var sunk_this_turn = []
var balls_active = [true, true, true, true, true, true, true, true, true]
var target_ball = 1
var game_over = false

var ball_list = []
var label_list = []
# What a horrendous violation of DRY coding
# I'll have to do the HeartBeast space shooter tutorial because it looks
# like it teaches how to make more organized code

signal reset_table()

func _ready():
	reset_point = cueball.position
	cueball.contact_monitor = true
	$Table/Polygon2D.polygon = $Table/CollisionPolygon2D.polygon
	$Table/Polygon2D.color = Color(0.41, 0.41, 0.41)
	
	ball_list = [
	$NormalBalls/ball1, $NormalBalls/ball2, $NormalBalls/ball3,
	$NormalBalls/ball4, $NormalBalls/ball5, $NormalBalls/ball6,
	$NormalBalls/ball7, $NormalBalls/ball8, $NormalBalls/ball9]
	
	label_list = [
	$SunkBallDisplay/ballabel1, $SunkBallDisplay/ballabel2, $SunkBallDisplay/ballabel3,
	$SunkBallDisplay/ballabel4, $SunkBallDisplay/ballabel5, $SunkBallDisplay/ballabel6,
	$SunkBallDisplay/ballabel7, $SunkBallDisplay/ballabel8, $SunkBallDisplay/ballabel9]
	for i in len(label_list):
		label_list[i].visible = false
	
	for i in len(ball_list):
		ball_list[i].connect("sunk", on_ball_sunk)

func _process(delta):
	
	# SET GUIDEPOINT AND LINE
	var mouse_to_ball_dist = (get_global_mouse_position() - cueball.position) * 0.7
	mouse_to_ball_dist = mouse_to_ball_dist.limit_length(max_mouse_dist * 0.7)
	guidepoint.position = cueball.position + mouse_to_ball_dist
	guideline.visible = shot_allowed and not game_over
	if mouse_to_ball_dist.length() > (max_mouse_dist * 0.7) - 1:
		guideline.default_color = Color(1,1,1)
	else:
		guideline.default_color = Color(0.7,0.7,0.7)
	guideline.set_point_position(0, cueball.position)
	guideline.set_point_position(1, guidepoint.position)
	
	# RESET TABLE
	if Input.is_action_just_pressed("reset_table"):
		reset_table.emit()
		reset_cueball()
	
	# CHECK IF ANYTHING ON TABLE IS MOVING
	# RUNS ONLY WHEN THE CUEBALL IS DAMPED
	# IF THIS RAN EVERY FRAME IT WOULD BE A NIGHTMARE
	if cueball.linear_velocity.length() < next_shot_limit == true and shot_allowed == false and shot_wait_timer.time_left == 0:
		var slowed_balls = 0
		for i in len(ball_list):
			if ball_list[i].linear_velocity.length() < next_shot_limit:
				slowed_balls += 1
		if slowed_balls == 9 and cueball_slowed == true:
			shot_allowed = true
			find_legality()
	

func _physics_process(delta):
	# LAUNCH CUEBALL ON CLICK
	# It's set up this way so cue_force and max_mouse_dist don't directly
	# interfere with each other
	if Input.is_action_just_pressed("click") and shot_allowed == true and game_over == false:
		var forcevector = get_global_mouse_position() - cueball.position
		forcevector = (forcevector.limit_length(max_mouse_dist)) / max_mouse_dist
		cueball.apply_impulse(forcevector * cue_force)
		shot_allowed = false
		shot_wait_timer.start()
		stroke_number += 1
		$StrokesLabel.text = str(stroke_number)
		target_ball = find_target_ball()
		print("Stroke ", stroke_number, ". Target ball: ", target_ball)
	
	# BRAKES
	if cueball.linear_velocity.length() > brake_limit:
		cueball.linear_damp = moving_damp
		cueball_slowed = false
	else:
		cueball.linear_damp = brake_damp
		cueball_slowed = true
	if cueball.visible == false:
		cueball.linear_damp = 10.0
	
	# DETECT POCKET, FOR REAL THIS TIME
	if cueball.get_contact_count() > 0:
		var collisions = cueball.get_colliding_bodies()
		for i in len(collisions):
			if collisions[i].is_in_group("pocket"):
				scratch()
	unscratch()

func scratch():
	cueball.set_collision_layer_value(1, false)
	cueball.set_collision_mask_value(1, false)
	cueball.visible = false
	scratch_count += 1
	$ScratchLabel.text = str(scratch_count)
	print("Scratch! Total scratches: ", scratch_count)

func unscratch():
	if cueball.visible == false:
		if shot_allowed == true:
			cueball.linear_velocity = Vector2.ZERO
			cueball.angular_velocity = 0
			cueball.rotation = 0
			cueball.global_transform.origin = reset_point
			cueball.set_collision_layer_value(1, true)
			cueball.set_collision_mask_value(1, true)
			cueball.visible = true
			

func reset_cueball():
	cueball.linear_velocity = Vector2.ZERO
	cueball.angular_velocity = 0
	cueball.rotation = 0
	cueball.global_transform.origin = reset_point
	cueball.set_collision_layer_value(1, true)
	cueball.set_collision_mask_value(1, true)
	cueball.visible = true
	scratch_count = 0
	stroke_number = 0
	game_over = false
	$StrokesLabel.text = "0"
	$ScratchLabel.text = "0"
	balls_active = [true, true, true, true, true, true, true, true, true]
	$Table/Polygon2D.color = Color(0.41, 0.41, 0.41)
	$CenterLabel.text = ""
	reset_sunk_display()
	print("Table reset.")

func on_ball_sunk(ID):
	print("You sunk the ", ID, "-Ball!")
	balls_active[ID-1] = false
	sunk_this_turn.append(ID)
	update_sunk_display()
	
	# 9-BALL CHECK
	

func find_target_ball():
	var loc_target_ball = 1
	while loc_target_ball <= 9:
		if balls_active[loc_target_ball - 1]:
			break
		else:
			loc_target_ball += 1
	return loc_target_ball

func find_legality():
	if sunk_this_turn.has(target_ball) or sunk_this_turn.size() == 0:
		print("Shot was legal.")
		if sunk_this_turn.has(9):
			victory()
	else:
		scratch_count += 1
		$ScratchLabel.text = str(scratch_count)
		print("Scratch! Ball sunk out of order. Total scratches: ", scratch_count)
		if stroke_number == 1:
			scratch_count -= len(sunk_this_turn)
			$ScratchLabel.text = str(scratch_count)
			print("Actually not, since that was the break")
		if sunk_this_turn.has(9):
			if stroke_number == 1:
				scratch_count -= 1
				$ScratchLabel.text = str(scratch_count)
				print("You got a 9-Break!")
				victory()
			else:
				trigger_game_over()
	if scratch_count < 1:
		$ScratchLabel.text = "0"
	sunk_this_turn.clear()

func victory():
	print("You win!")
	$Table/Polygon2D.color = Color(0.31, 0.58, 0.4)
	$CenterLabel.text = "You win!\nPress R to restart"

func trigger_game_over():
	game_over = true
	print("You sunk the 9 illegally. Game over.")
	$Table/Polygon2D.color = Color(0.57, 0.33, 0.31)
	$CenterLabel.text = "Game Over\nYou sunk the 9-ball\nillegally.\nPress R to restart"
	
func update_sunk_display():
	for i in len(label_list):
		label_list[i].visible = not balls_active[i]

func reset_sunk_display():
	for i in len(label_list):
		label_list[i].visible = false
