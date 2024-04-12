class_name PlayerController
extends CharacterBody3D


var GRAVITY: float = ProjectSettings.get_setting("physics/3d/default_gravity")/2.0


@export var gravity_body: Node3D

@export var move_speed: float = 4.0
@export var mouse_sensitivity: float = 0.002
@export var look_min: float = -90.0
@export var look_max: float = 90.0

@export var gravity_direction: Vector3 = Vector3.DOWN
var target_gravity_direction: Vector3 = Vector3.DOWN
var local_velocity: Vector3 = Vector3.ZERO

@onready var cam_pivot: Node3D = $CamPivotX
@onready var surface_check: RayCast3D = $SurfaceCheck


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
			
			cam_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
			cam_pivot.rotation.x = clamp(cam_pivot.rotation.x, deg_to_rad(look_min), deg_to_rad(look_max))


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if Input.is_action_just_pressed("ui_accept"):
		jump()
	
	
func _physics_process(delta: float) -> void:
	update_orientation(delta)
	apply_gravity(delta)
	
	var input_dir: Vector2 = get_move_input()
	move(input_dir)
	
	
func jump() -> void:
	if is_on_floor() == true:
		velocity += up_direction * 8
	
	
func apply_gravity(delta: float) -> void:
	if !is_on_floor():
		velocity += (gravity_direction * GRAVITY) * delta
		
		
func move(direction: Vector2) -> void:
	var move_dir: Vector3 = (transform.basis * Vector3(direction.x, 0.0, direction.y)).normalized()
	local_velocity = global_basis.inverse() * (velocity + move_dir * 0.25)
	
	if move_dir.length_squared() > 0:
		var y_vel: float = local_velocity.y
		local_velocity.y = 0.0 #
		local_velocity = local_velocity.limit_length(6.0)
		local_velocity.y = y_vel
	else:
		local_velocity.x *= 0.9
		local_velocity.z *= 0.9
		
	velocity = global_basis * local_velocity
	
	move_and_slide()
	

func get_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
	

func update_orientation(delta: float) -> void:
	# If we don't have any gravity bodies set, then do gravity like in the original Prey
	if gravity_body == null:
		# If we are in the air, make our raycast point in the direction of movement
		if is_on_floor() == false:
			var surface_check_target_pos: Vector3 = local_velocity.normalized() * 5
			surface_check.target_position = surface_check_target_pos
		else: # Otherwise, raycast down relative to players orientation
			surface_check.target_position = Vector3(0.0, -5.0, 0.0)
		
		# Now that we know where our raycast target position is cast ray and if it's colliding...
		if surface_check.is_colliding() == true:
			var col = surface_check.get_collider()
			# If we are falling down relative to players orientation
			if local_velocity.y <= 1:
				# Set our target gravity direction to be negative the surface collision normal direction
				set_target_gravity_direction(-surface_check.get_collision_normal())
	else: # If we DO have a gravity body set
		# Get direction to gravity body from player
		var g_dir: Vector3 = global_transform.origin.direction_to(gravity_body.global_transform.origin)
		set_target_gravity_direction(g_dir.normalized())
			
	# Update the players global basis based on new target gravity direction
	var new_basis: Basis = global_basis
	new_basis.y = -target_gravity_direction
	new_basis.x = -new_basis.z.cross(-target_gravity_direction)
	new_basis = new_basis.orthonormalized()
	global_basis = lerp(global_basis, new_basis, 5 * delta)
	
	# apply gravity direction and update up direction
	gravity_direction = target_gravity_direction
	up_direction = -gravity_direction
	
	
func set_target_gravity_direction(direction: Vector3) -> void:
	target_gravity_direction = direction
