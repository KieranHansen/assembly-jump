#####################################################################
#
# CSCB58 Winter 2023 Assembly Final Project
# University of Toronto, Scarborough
#
# Student: Kieran Hansen, 1007062474, Hansen20, kieran.hansen@mail.utoronto.ca
#
# Bitmap Display Configuration:
# - Unit width in pixels: 4
# - Unit height in pixels: 4
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 3 (choose the one the applies)
#
# Which approved features have been implemented for milestone 3?
# (See the assignment handout for the list of additional features)
# 1. Moving Platforms (2 Marks)
# 2. Animated Sprite (2 Marks)
# 3. Shoot Enemies (2 Marks)
# 4. Fail Condition (1 Mark)
# 5. Win Condition (1 Mark)
# 6. Score (2 Marks)
# 7. Moving Objects/Monsters (2 Marks) - They shift with the camera, Does this count?
#
# Link to video demonstration for final submission:
# - https://youtu.be/N_2T1b_waN8
#
# Are you OK with us sharing the video with people outside course staff?
# - yes
#
# Any additional information that the TA needs to know:
# - Controls are W,A,D to move, J to shoot, P to restart the game
#
#####################################################################

#Important Note:
# - registers t0 and t1 are not to be used besides storing player coordinates.
# - register t2 holds previous platform X - do not touch

#Setting some useful constants for things like locations and color
.eqv BASE_ADDRESS 0x10008000
.eqv KEYPRESS_ADDRESS 0xffff0000

.eqv BG_GREEN 0xb2b47e
.eqv DARK_GREEN 0x4e584a
.eqv MAIN_GREEN 0x6b7966
.eqv WHITE 0xf2f0e5

.eqv SLEEP_TIME 40

.eqv MOVE_SPEED_R 4
.eqv MOVE_SPEED_L -4
.eqv JUMP_SPEED -6
.eqv FALL_SPEED 1
.eqv MAX_FALL_SPEED 1

.eqv START_X 30
.eqv START_Y 47
.eqv MIN_X 2
.eqv MAX_X 57
.eqv MIN_Y 2
.eqv MAX_Y 52

.eqv CAMERA_SPEED 3
.eqv CAMERA_HEIGHT 47

.eqv PLAT_ONE_X 27
.eqv PLAT_ONE_Y 57
.eqv NUM_PLATFORMS 4
.eqv PLAT_SPEED_L -1
.eqv PLAT_SPEED_R 1
.eqv MAX_PLAT_X 50
.eqv MIN_PLAT_X 4
.eqv NORMAL_PLAT 0
.eqv MOVING_PLAT 1
.eqv TRAMP_PLAT 2
.eqv TRAMP_BOUNCE -6
.eqv PLATFORM_SIZE 12

.eqv NUM_MONSTERS 2
.eqv MON_MAX_X 55
.eqv MON_MIN_X 4
.eqv MON_SIZE 10
.eqv MON_ONE_Y 45
.eqv MON_TWO_Y 15

.eqv BUL_SIZE 10
.eqv BUL_SPEED -2
.eqv BUL_NUM 3
.eqv BUL_DEF_XY 2

.eqv GAME_OVER_X 20
.eqv GAME_OVER_Y 24

.eqv SB_X 25
.eqv SB_Y 4
.eqv SB_BY 33

.eqv WIN_X 14
.eqv WIN_Y 28
.eqv WIN_POINTS 50

# Use this section to define things in memory
.data
player: .space 16 #half words X, Y, Vy, Sc, bytes G, Sh, Vx, By, D
platforms: .space 48 #array of 4 structs made of half words X, Y, T, V, Px, Py
monsters: .space 20 #array of two monsters made up of half words X, Y, Px, Py, A
bullets: .space 32 #index 0 is the number of currently visible bullets, then from index 2, half word structs of X, Y, Px, Py, V
scoreboard: .space 6 #3 half words, Total, Tens, Ones

.text

# ------ Main Program ----- #

.globl main
main:	
	# --- Initialization Section --- #
	start_game:
	# Begin by drawing the scene
	jal draw_empty_scene
	
	#Init and draw the player at start pos next.
	jal init_player
	jal init_platforms
	jal init_monsters
	jal init_bullets
	jal init_scoreboard
	
	jal draw_platforms
	jal draw_player_sprite
	jal draw_scoreboard

	# ------------------------------ #
	
	# --- Gameplay Loop --- #
	main_game_loop:
	
		#Check if a player has pressed a button and update info accordingly
		li $t9, KEYPRESS_ADDRESS
		lw $t8, 0($t9)
		beq $t8, 1, player_keypress_event
		
	    main_post_keypress:
		
		#Given the new data for the player, update position data
		jal update_player_location
		jal spawn_bullet
		
		#Update Platforms/Monsters/Bullets
		jal update_platform_location #update prev coords and move moving platforms
		jal update_bullet_location #update prev coords
		jal update_monster_location #update previous coordinates
		
		#Check for player collision with platforms/monsters
		jal platform_collision_check #check if player has hit a platform
		jal bullet_collision_check #check if bullet has hit a monster
		jal monster_collision_check #check if player has hit a monster
		jal update_scoreboard #check if the player has achieved a new best y and update scoreboard
		
		#Check if the camera needs to be shifted down, and do so
		jal shift_camera_down
		
		#quickly redraw the sprites present on screen in this order:
		#  Monsters, Platforms, Bullets, Player, Score
		jal draw_monsters
		jal draw_platforms
		jal draw_bullets
		jal draw_player_sprite
		jal draw_scoreboard
		
		#Update the player to no longer be shooting
		jal stop_player_shooting
		
		#Check if the player has won or lost the game, either touched a monster/floor or points = POINTS_WIN
		jal check_game_loss
		jal check_game_win
		
		#Finally, sleep for a little bit before repeating the loop
		li $v0, 32
		li $a0, SLEEP_TIME
		syscall 
				
		j main_game_loop
	
	# --------------------- #
	
	# terminate the program gracefully
	li $v0, 10 
	syscall

# End of main program

# ---------------------------#
	
#---------- Function to Draw the Initial Scene -------------- #

# This function will draw the 'gameboy' style initial screen without
# any of the content. This operates on constant value and so requires
# register preperation (essentially a void func).

draw_empty_scene:
	li $s0, BASE_ADDRESS #Set s0 to the start of the drawing buffer
	li $s1, BG_GREEN #Set the colour to paint with.
	addi $s2, $s0, 16384 #Set the address of the final pixel to color.
	
	# Fill in the whole background with the given color via a loop.
	des_background_color_fill:
	sw $s1, 0($s0)
	addi $s0, $s0, 4
	bne $s0, $s2, des_background_color_fill

	# Fill the outer horizontal ring with dark green
	li $s0, BASE_ADDRESS
	li $s1, DARK_GREEN
	addi $s2, $s0, 256

	des_border_one_hfill:
	sw $s1, 0($s0)
	sw $s1, 16128($s0)
	addi $s0, $s0, 4
	bne $s0, $s2, des_border_one_hfill
	
	# Fill the outer vertical ring with dark green
	li $s0, BASE_ADDRESS
	addi $s2, $s0, 16128
	
	des_border_one_vfill:
	sw $s1, 0($s0)
	sw $s1, 252($s0)
	addi $s0, $s0, 256
	bne $s0, $s2, des_border_one_vfill

	# Fill the inner white horizontal ring
	li $s0, BASE_ADDRESS
	li $s1, WHITE
	addi $s2, $s0, 248

	des_border_two_hfill:
	sw $s1, 260($s0)
	sw $s1, 15876($s0)
	addi $s0, $s0, 4
	bne $s0, $s2, des_border_two_hfill
	
	# Fill the inner white vertical ring
	li $s0, BASE_ADDRESS
	addi $s2, $s0, 15616
	
	des_border_two_vfill:
	sw $s1, 260($s0)
	sw $s1, 504($s0)
	addi $s0, $s0, 256
	bne $s0, $s2, des_border_two_vfill

	jr $ra

# End of Initial Drawing Function
# ----------------------------------------------------------- #

# --------- Draw Character Function --------- # 
# The characters sprite can change based on the action it is taking
# so not only do we need to know the position of the character, but
# also if it is shooting, or on the ground. We read this information
# from our saved memory.

draw_player_sprite:
	
	#We first erase the old player sprite
	move $s7, $ra
	jal remove_prev_player_sprite
	move $ra, $s7
	
	# Then start by loading the necessary information to draw the sprite
	# into our S registers.
	la $s0, player #store address of our player
	lh $s1, 0($s0) #store x coord of player (2 - 56)
	lh $s2, 2($s0) #store y coord of player (2 - 53)
	lb $s3, 8($s0) #store G
	
	#set colors
	li $s6, MAIN_GREEN
	li $s5, BG_GREEN
	li $s4, DARK_GREEN

	li $s7, BASE_ADDRESS #Store base address for drawing
	#multiply the x coordinate by 4 and the y coordinate by 256
	sll $s1, $s1, 2
	sll $s2, $s2, 8
	
	# change the base address to the offset of the player
	add $s7, $s7, $s1
	add $s7, $s7, $s2
	
	#check if character is jumping
	beq $s3, $zero, draw_jumping_char
	
	#check if character is shooting
	lb $s3, 9($s0)
	beq $s3, 1, draw_standing_shooting_char
	
    #draw the basic model of the character.
    draw_standing_char:
	sw $s6, 772($s7) #row 4
	sw $s6, 776($s7)
	sw $s6, 780($s7)
	
	sw $s6, 1024($s7) #row 5
	sw $s4, 1028($s7)
	sw $s6, 1032($s7)
	sw $s4, 1036($s7)
	sw $s6, 1040($s7)
	
	sw $s6, 1280($s7) #row 6
	sw $s6, 1284($s7)
	sw $s6, 1288($s7)
	sw $s6, 1292($s7)
	sw $s6, 1296($s7)
	
	sw $s6, 1536($s7) #row 7
	sw $s6, 1540($s7)
	sw $s6, 1544($s7)
	sw $s6, 1548($s7)
	sw $s6, 1552($s7)
	
	sw $s6, 1792($s7) #row 8
	sw $s6, 1796($s7)
	sw $s6, 1800($s7)
	sw $s6, 1804($s7)
	sw $s6, 1808($s7)
	
	sw $s4, 2052($s7)#row 9
	sw $s4, 2060($s7)
	
	sw $s4, 2304($s7) #row 10
	sw $s4, 2308($s7)
	sw $s4, 2316($s7)
	sw $s4, 2320($s7)
	
	jr $ra
	
    draw_standing_shooting_char:
	
	sw $s6, 260($s7) #row 2
	sw $s6, 264($s7)
	sw $s6, 268($s7)

	sw $s6, 520($s7) #row 3
	
	sw $s6, 772($s7) #row 4
	sw $s6, 776($s7)
	sw $s6, 780($s7)
	
	sw $s6, 1024($s7) #row 5
	sw $s4, 1028($s7)
	sw $s6, 1032($s7)
	sw $s4, 1036($s7)
	sw $s6, 1040($s7)
	
	sw $s6, 1280($s7) #row 6
	sw $s6, 1284($s7)
	sw $s6, 1288($s7)
	sw $s6, 1292($s7)
	sw $s6, 1296($s7)
	
	sw $s6, 1536($s7) #row 7
	sw $s6, 1540($s7)
	sw $s6, 1544($s7)
	sw $s6, 1548($s7)
	sw $s6, 1552($s7)
	
	sw $s6, 1792($s7) #row 8
	sw $s6, 1796($s7)
	sw $s6, 1800($s7)
	sw $s6, 1804($s7)
	sw $s6, 1808($s7)
	
	sw $s4, 2052($s7) #row 9
	sw $s4, 2060($s7)
	
	sw $s4, 2304($s7) #row 10
	sw $s4, 2308($s7)
	sw $s4, 2316($s7)
	sw $s4, 2320($s7)
	
	jr $ra
	
    draw_jumping_char:	
	#check if character is shooting
	lb $s3, 9($s0)
	beq $s3, 1, draw_jumping_shooting_char
		 
	sw $s6, 516($s7) #row 3
	sw $s6, 520($s7)
	sw $s6, 524($s7)
	
	sw $s6, 768($s7) #row 4
	sw $s4, 772($s7)
	sw $s6, 776($s7)
	sw $s4, 780($s7)
	sw $s6, 784($s7)
	
	sw $s6, 1024($s7) #row 5
	sw $s6, 1028($s7)
	sw $s6, 1032($s7)
	sw $s6, 1036($s7)
	sw $s6, 1040($s7)
	
	sw $s6, 1280($s7) #row 6
	sw $s6, 1284($s7)
	sw $s6, 1288($s7)
	sw $s6, 1292($s7)
	sw $s6, 1296($s7)
	
	sw $s6, 1536($s7) #row 7
	sw $s6, 1540($s7)
	sw $s6, 1544($s7)
	sw $s6, 1548($s7)
	sw $s6, 1552($s7)
	
	sw $s4, 1796($s7) #row 8
	sw $s4, 1804($s7)
	
	sw $s4, 2052($s7) #row 9
	sw $s4, 2060($s7)
	
	sw $s4, 2308($s7) #row 10
	sw $s4, 2316($s7)
	
	jr $ra
	
    draw_jumping_shooting_char:
    	
	sw $s6, 4($s7) #row 1
	sw $s6, 8($s7)
	sw $s6, 12($s7)
	
	sw $s6, 264($s7) #row 2
	
	sw $s6, 516($s7) #row 3
	sw $s6, 520($s7)
	sw $s6, 524($s7)
	
	sw $s6, 768($s7) #row 4
	sw $s4, 772($s7)
	sw $s6, 776($s7)
	sw $s4, 780($s7)
	sw $s6, 784($s7)
	
	sw $s6, 1024($s7) #row 5
	sw $s6, 1028($s7)
	sw $s6, 1032($s7)
	sw $s6, 1036($s7)
	sw $s6, 1040($s7)
	
	sw $s6, 1280($s7) #row 6
	sw $s6, 1284($s7)
	sw $s6, 1288($s7)
	sw $s6, 1292($s7)
	sw $s6, 1296($s7)
	
	sw $s6, 1536($s7) #row 7
	sw $s6, 1540($s7)
	sw $s6, 1544($s7)
	sw $s6, 1548($s7)
	sw $s6, 1552($s7)
	
	sw $s4, 1796($s7) #row 8
	sw $s4, 1804($s7)

	sw $s4, 2052($s7) #row 9
	sw $s4, 2060($s7)
	
	sw $s4, 2308($s7) #row 10
	sw $s4, 2316($s7)
    	
    	jr $ra
	
	
# End of draw player function
# ------------------------------------------- #

# ------------ Init Player Function --------- #
# I moved the init function here to remove clutter 
# from the main. Just set the values for char
# to be what we have in the eqv section.

init_player:
	la $s0, player
	li $s1, START_X #X
	li $s2, START_Y #Y
	li $s3, 0 # Vy
	li $s4, 0 # Sc
	li $s5, 1 # G
	li $s6, 0 # Sh
	li $s7, 0 # Vx
	
	#Store the loaded values in memory
	sh $s1, 0($s0)
	sh $s2, 2($s0)
	sh $s3, 4($s0)
	sh $s4, 6($s0)
	sb $s5, 8($s0)
	sb $s6, 9($s0)
	sb $s7, 10($s0)
	sh $s2, 12($s0) # By = Y
	sh $zero, 14($s0) # D = 0
	
	#init the player location in the t registers
	move $t0, $s1
	move $t1, $s2
	
	jr $ra
	
# End of the init player function	
# -----------------------------------------------#

# ------------ Keypress Event Function --------- #
# We jump to this function whenever we run through the main
# gameplay loop and find a new key was pressed. There are
# 7 different cases for a keypress, jump (w), left (a),
# right (d), shoot (j), reset (p), and then anything else (junk).

# Reaching here means that $t9, and $t8 hold the values for reading
# the keystroke event
player_keypress_event:
	# Get the key that was pressed
	lw $t8, 4($t9)
	beq $t8, 0x77, player_pressed_w
	beq $t8, 0x61, player_pressed_a
	beq $t8, 0x64, player_pressed_d
	beq $t8, 0x6a, player_pressed_j
	beq $t8, 0x70, player_pressed_p
	
	# If we haven't branched, it was an invalid character, just go
	# back to main
	j main_post_keypress
	
	#Function names from here on are pretty self explanitory
	player_pressed_w:
		#Check if the player is on the ground, if so, then jump
		#otherwise nothing happens
		
		#Load in relevant player information
		la $s0, player
		lb $s1, 8($s0) #player on ground
		
		#If the player is on the ground, set the velocity to the JUMP_SPEED value
		#Otherwise nothing changes
		bne $s1, 1, main_post_keypress
		
		#Update the velocity field in the player struct
		li $s2, JUMP_SPEED
		sh $s2, 4($s0)
		sb $zero, 8($s0) #if they can jump, they are no longer on the ground
		
		#Go back to main
		j main_post_keypress
	
	player_pressed_a:
		# Adjust the player one pixel to the left, check if this
		# creates an issue with boundaries (min x)
		
		#Load in relevant player information
		la $s0, player
		#lh $s1, 0($s0) #X
		
		#Check if X is already the minimum allowed value
		#beq $s1, MIN_X, main_post_keypress
		
		#If we aren't at the minimum value we can safely set Vx to -
		li $s1, MOVE_SPEED_L
		sh $s1, 10($s0)
		
		#...and return to the main loop
		j main_post_keypress
		
	
	player_pressed_d:
		# Adjust the player one pixel to the right, check if this
		# creates an issue with boundaries (max x)
		
		#Load in relevant player information
		la $s0, player
		#lh $s1, 0($s0) #X
		
		#Check if X is already the minimum allowed value
		#beq $s1, MAX_X, main_post_keypress
		
		#If we aren't at the minimum value we can safely set Vx to one
		li $s1, MOVE_SPEED_R
		sh $s1, 10($s0)
		
		#...and return to the main loop
		j main_post_keypress
		
	player_pressed_j:
		# Set the value for character shooting to true. This will be implemented eventually.
		# only let this happen if there are less than three bullets on the screen
		
		la $s0, bullets
		lh $s0, 0($s0)
		
		beq $s0, BUL_NUM, main_post_keypress #go back to main if too many bullets
		
		la $s0, player
		li $s1, 1
		sb $s1, 9($s0)
		
		j main_post_keypress
	
	player_pressed_p:
		#Restart the game and re-initialize everything.
		j start_game
	
# End of keypress event function
# ---------------------------------------------- #

# ---------- Update Player Location ----------- #
# Taking the results of the players keypress action, update the
# position of the player accordingly.

update_player_location:
	#Load in necessary information about the player (velocities/coordinates)
	la $s0, player
	lh $s1, 0($s0) # X
	lh $s2, 2($s0) # Y
	lh $s3, 4($s0) # Vy
	lb $s4, 10($s0) # Vx
	lb $s5, 8($s0) # G
	
	#Store former X and Y in registers t0, t1
	move $t0, $s1
	move $t1, $s2
	
	# Calculate new X coordinate
	add $s1, $s1, $s4
	
    pre_fix_right_boundary:
    	bgt $s1, MIN_X, pre_fix_left_boundary
    	li $s1, MIN_X
    
    pre_fix_left_boundary:
    	blt $s1, MAX_X, post_fix_left_boundary
    	li $s1, MAX_X
	
    post_fix_left_boundary:
	# Update X coordinate and reset x velocity
	sh $s1, 0($s0)
	sb $zero, 10($s0)
 
	
	# Update the Y Coordinate by adding velocity. Update velocity by adding fall speed
	# As Y coordinate is more complicated than X, confirm they are not going out of
	# bounds here
	
	# Y coordinate only needs to update if the player is in the air
	beq $s5, $zero, upl_player_in_air
	# Otherwise can just return. No need to calc change in Y
	# if the player is on the ground
	jr $ra
    
    upl_player_in_air:
	add $s2, $s2, $s3 
	addi $s3, $s3, FALL_SPEED
	
    upl_fix_top_boundary:
    	bgt $s2, MIN_Y, upl_fix_bottom_boundary
    	li $s2, MIN_Y
    
    upl_fix_bottom_boundary:
    	blt $s2, MAX_Y, upl_fix_falling_speed
    	li $s2, MAX_Y
	
    upl_fix_falling_speed:
	li $s7, MAX_FALL_SPEED
	sgt $s7, $s3, $s7
	
	beq $s7, 0, post_fix_falling_speed

	#fix the falling speed to be no larger than MAX_FALL_SPEED
	li $s3, MAX_FALL_SPEED
	
    post_fix_falling_speed:	
	sh $s2, 2($s0)
	sh $s3, 4($s0)
	
	jr $ra

# End of location update function
# ---------------------------------------------- #

# ---------- Update Platform Locations ------- # 
# This function goes through and updates the location
# values of the platforms. This means updating the previous
# x and y values with the new ones, and for moving type platforms
# shifting their x-coordinates.

update_platform_location:
	#Load in the platforms array and the iterator
	la $s0, platforms # load the platforms
	li $s1, 0 #iterator
	
    upl_loop:
    	#First update the former x and y locations
    	lh $s2, 2($s0)
    	sh $s2, 10($s0) #py
    	lh $s2, 0($s0) 
    	sh $s2, 8($s0) #px
    	
    	#If the platform is of type TRAMP_PLAT, we modify the x value
    	#Otherwise we just iterate to the next platform.
    	
    	#load the type
    	lh $s2, 4($s0)
   	bne $s2, MOVING_PLAT, upl_iterate
    
    	# If it is a moving platform then we need to try to update the X value
    	# If doing so with the current Velocity puts it out of bounds then we flip
    	# the velocity and send it on its way
    	lh $s2, 0($s0) # X
    	lh $s3, 6($s0) # V
    
    	add $s2, $s2, $s3
    
    #Check if out of bounds to the left, if it is, correct and change direction of V to right
    upl_check_left:
	blt $s2, MAX_PLAT_X, upl_check_right 
    	#Flip velocity to move left, and update the X to match this change
    	li $s3, PLAT_SPEED_L
    	add $s2, $s2, $s3
    	add $s2, $s2, $s3
    	
    upl_check_right:
    	bgt $s2, MIN_PLAT_X, upl_update
    	#Flip velocity to move right, and update the X to match this change
    	li $s3, PLAT_SPEED_R
    	add $s2, $s2, $s3
    	add $s2, $s2, $s3
    
    upl_update:
    	sh $s2, 0($s0) #store new X
    	sh $s3, 6($s0) #store new V
    	
    upl_iterate:
    	addi $s0, $s0, PLATFORM_SIZE
    	addi $s1, $s1, 1
    	bne $s1, NUM_PLATFORMS, upl_loop
    	
    	jr $ra

# End of platform location update
# -------------------------------------------- #

# ------ Erase Old Player Sprite ------ #
# This function will use register based calling for
# for speed as it really only needs two values, the X and Y coords
# This function requires X in t0 and Y in t1 to be called.
# This function will not touch anything is s registers.

remove_prev_player_sprite:
	#kinda tricky way of turning the coordinates into the address 
	# of the top left pixel.
	sll $t0, $t0, 2
	sll $t1, $t1, 8
	add $t1, $t1, $t0
	li $t0, BASE_ADDRESS 
	add $t0, $t0, $t1
	
	# could use a loop but I'm too lazy so I'm just manually resetting all
	# of the pixels to the BG color.
	li $t1, BG_GREEN
	
	#sw $a1, 0($a0) #row 1
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	#sw $a1, 16($a0)
	
	#sw $a1, 256($a0) #row 2
	sw $t1, 260($t0)
	sw $t1, 264($t0)
	sw $t1, 268($t0)
	#sw $a1, 272($a0)
	
	#sw $a1, 512($a0) #row 3
	sw $t1, 516($t0)
	sw $t1, 520($t0)
	sw $t1, 524($t0)
	#sw $a1, 528($a0)
	
	sw $t1, 768($t0) #row 4
	sw $t1, 772($t0)
	sw $t1, 776($t0)
	sw $t1, 780($t0)
	sw $t1, 784($t0)
	
	sw $t1, 1024($t0) #row 5
	sw $t1, 1028($t0)
	sw $t1, 1032($t0)
	sw $t1, 1036($t0)
	sw $t1, 1040($t0)
	
	sw $t1, 1280($t0) #row 6
	sw $t1, 1284($t0)
	sw $t1, 1288($t0)
	sw $t1, 1292($t0)
	sw $t1, 1296($t0)
	
	sw $t1, 1536($t0) #row 7
	sw $t1, 1540($t0)
	sw $t1, 1544($t0)
	sw $t1, 1548($t0)
	sw $t1, 1552($t0)

	sw $t1, 1792($t0) #row 8
	sw $t1, 1796($t0)
	sw $t1, 1800($t0)
	sw $t1, 1804($t0)
	sw $t1, 1808($t0)

	#sw $a1, 2048($a0) #row 9
	sw $t1, 2052($t0)
	#sw $a1, 2056($a0)
	sw $t1, 2060($t0)
	#sw $a1, 2064($a0)
	
	sw $t1, 2304($t0) #row 10
	sw $t1, 2308($t0)
	#sw $a1, 2312($a0)
	sw $t1, 2316($t0)
	sw $t1, 2320($t0)
	
	jr $ra

# End of old player sprite eraser
# ------------------------------------- #

# ---------- Platform Initializer ------- #
# This function performs the initialization of the first four platforms that the player will see
# in this game there are only four platforms which are reused to save resources.
# The first (bottommost) platform will always be the same, but the rest will generate randomly relative to the first

init_platforms:
	# Load the address for platforms in memory
	la $s0, platforms
	li $s1, 1
	
	#Load the information for this first platform
	li $s2, PLAT_ONE_X
	li $s3, PLAT_ONE_Y
	li $s4, NORMAL_PLAT
	
	#Create the first platform
	sh $s2, 0($s0)
	sh $s3, 2($s0)
	sh $s4, 4($s0)
	sh $zero, 6($s0)
	sh $s2, 8($s0)
	sh $s3, 10($s0)
	
	#Shift s0 to the next index
	addi $s0, $s0, PLATFORM_SIZE 
	
	# The position of each platform after the first will depend on the position of the one that came before
	# this is to ensure that platforms are reachable despite being random.
    init_platform_loop:
    	beq $s1, NUM_PLATFORMS, exit_init_platform_loop
    	
    	#s5 and s6 hold the max and min shift, but need to correct in case these values go beyond range
    	addi $s5, $s2, -20 #min
    	addi $s6, $s2, 20 #max
    	
    	init_fix_platform_min_value:
    	bge $s5, MIN_PLAT_X, init_fix_platform_max_value 
    	li $s5, MIN_PLAT_X 
    	 
    	init_fix_platform_max_value:
    	ble $s6, MAX_PLAT_X, init_generate_platform_value
    	li $s6, MAX_PLAT_X 
    	
    	init_generate_platform_value:
    	#s6 - s5 will give us the size of the range for our random value 
    	sub $a1, $s6, $s5 
    	
    	#get our random number
    	li $v0, 42
    	li $a0, 0
    	syscall
    	
    	#move the generated number into $s2 for future iterations
    	#also update the height to be 15 higher than the last platform
    	add $s2, $s5, $a0
    	addi $s3, $s3, -15
    	
    	#Save the generated platform to memory also update t2 
	sh $s2, 0($s0)
	sh $s3, 2($s0)
	sh $s4, 4($s0)
	sh $zero, 6($s0)
	sh $s2, 8($s0)
	sh $s3, 10($s0)
	move $t2, $s2
    	
    	#increment counter and loop
    	addi $s0, $s0, PLATFORM_SIZE
    	addi $s1, $s1, 1
    	j init_platform_loop
    	
    exit_init_platform_loop:
    	jr $ra
    	
# End of Platform Initializer
# --------------------------------------- #

# ------- Platform Drawing Function ----- #

draw_platforms:
	la $s0, platforms
	li $s1, 0
	
    draw_platforms_loop:
	beq $s1, NUM_PLATFORMS, draw_platforms_end_loop 
	
	#Erase the platforms previous sprite
	move $s7, $ra
	lh $a0, 8($s0)
	lh $a1, 10($s0)
	jal erase_platform_sprite
	move $ra, $s7
	
	#load the base address for drawing
	li $s2, BASE_ADDRESS
	lh $s4, 0($s0)
	lh $s5, 2($s0)
	
	#adjust drawing address to platform coordinates
	sll $s4, $s4, 2
	sll $s5, $s5, 8
	add $s2, $s2, $s4
	add $s2, $s2, $s5
	
	lh $s3, 4($s0)
	beq $s3, MOVING_PLAT, draw_moving_platform
	beq $s3, TRAMP_PLAT, draw_tramp_platform
	
	draw_normal_platform:
	li $s3, MAIN_GREEN
	    sw $s3, 0($s2)
	    sw $s3, 4($s2)
	    sw $s3, 8($s2)
	    sw $s3, 12($s2)
	    sw $s3, 16($s2)
	    sw $s3, 20($s2)
	    sw $s3, 24($s2)
	    sw $s3, 28($s2)
	    sw $s3, 32($s2)
	    sw $s3, 36($s2)
	    
	    sw $s3, 256($s2)
	    sw $s3, 260($s2)   
	    sw $s3, 264($s2)   
	    sw $s3, 268($s2)   
	    sw $s3, 272($s2)   
	    sw $s3, 276($s2)   
	    sw $s3, 280($s2)   
	    sw $s3, 284($s2)   
	    sw $s3, 288($s2)   
	    sw $s3, 292($s2)
	    j dp_increment_and_loop
	    
	draw_moving_platform:
	li $s3, DARK_GREEN
	    sw $s3, 0($s2)
	    sw $s3, 4($s2)
	    sw $s3, 8($s2)
	    sw $s3, 12($s2)
	    sw $s3, 16($s2)
	    sw $s3, 20($s2)
	    sw $s3, 24($s2)
	    sw $s3, 28($s2)
	    sw $s3, 32($s2)
	    sw $s3, 36($s2)
	    
	    sw $s3, 256($s2)
	    sw $s3, 260($s2)   
	    sw $s3, 264($s2)   
	    sw $s3, 268($s2)   
	    sw $s3, 272($s2)   
	    sw $s3, 276($s2)   
	    sw $s3, 280($s2)   
	    sw $s3, 284($s2)   
	    sw $s3, 288($s2)   
	    sw $s3, 292($s2)
	    j dp_increment_and_loop
	    
	draw_tramp_platform:
	li $s3, WHITE
	li $s4, DARK_GREEN 
	
	    sw $s4, 0($s2)
	    sw $s3, 4($s2)
	    sw $s3, 8($s2)
	    sw $s3, 12($s2)
	    sw $s3, 16($s2)
	    sw $s3, 20($s2)
	    sw $s3, 24($s2)
	    sw $s3, 28($s2)
	    sw $s3, 32($s2)
	    sw $s4, 36($s2)
	    
	    sw $s4, 260($s2)   
	    sw $s4, 264($s2)   
	    sw $s4, 268($s2)   
	    sw $s4, 272($s2)   
	    sw $s4, 276($s2)   
	    sw $s4, 280($s2)   
	    sw $s4, 284($s2)   
	    sw $s4, 288($s2)   
	   
	    j dp_increment_and_loop       
	
    dp_increment_and_loop:
	#increment and loop
	addi $s0, $s0, PLATFORM_SIZE
	addi $s1, $s1, 1
	j draw_platforms_loop
	
    draw_platforms_end_loop:
    	jr $ra

# End of function that draws platforms
# --------------------------------------- #

# --------------- Erase Platforms ------------ #
# This function takes the x and y value stored in a0 and a1
# and erases the platform there.

erase_platform_sprite:
	#load the base address for drawing
	li $s2, BASE_ADDRESS
	li $s3, BG_GREEN
	
	sll $a0, $a0, 2
	sll $a1, $a1, 8
	add $s2, $s2, $a0
	add $s2, $s2, $a1
	
	sw $s3, 0($s2)
	sw $s3, 4($s2)
	sw $s3, 8($s2)
	sw $s3, 12($s2)
	sw $s3, 16($s2)
	sw $s3, 20($s2)
	sw $s3, 24($s2)
	sw $s3, 28($s2)
	sw $s3, 32($s2)
	sw $s3, 36($s2)
	
	sw $s3, 256($s2)
	sw $s3, 260($s2)   
	sw $s3, 264($s2)   
	sw $s3, 268($s2)   
	sw $s3, 272($s2)   
	sw $s3, 276($s2)   
	sw $s3, 280($s2)   
	sw $s3, 284($s2)   
	sw $s3, 288($s2)   
	sw $s3, 292($s2) 
	
	jr $ra
# -------------------------------------- #
	

# ----------- Check Platform Collision ------------ #
# This function updates the G value of the player if they
# have landed on a platform. A player is considered "landed"
# if they are falling (Vy > 0) and their coordinates are above those
# of a platform
platform_collision_check:
	# To perform this check we need the X and Y coordinates
	# Of the player as well as their Y velocity
	
	# We will use s0 - s3 to hold this information about the player.
	la $s0, player
	lh $s1, 0($s0) # X
	lh $s2, 2($s0) # Y
	lh $s3, 4($s0) # Vy
	
	# If the players velocity is less than 0, then they cannot be on the ground as they are jumping.
	# Thus we can set the players G value to 0, and return early.
	bge $s3, 0, pcc_player_is_falling

    pcc_player_is_rising:
	# Set G to false and return
	sb $zero, 8($s0)
	jr $ra
	
    pcc_player_is_falling:
	# With this information, we now need the platform information (s4-s7)
	#We also know that the player is falling, so we can discard our Vy
	la $s3, platforms
	li $s4, 0 #incrementor
	
    pcc_check_platform_loop:
    	#First check that they player is at the correct Y level
    	lh $s5, 2($s3) # Py
    	addi $s5, $s5, -10
    	
    	bne $s5, $s2, pcc_next_iteration
    	
    	#If we reach here, then the Y is correct, so we need to check that the player is in bounds of the platform
    	lh $s5, 0($s3) #Px
    	addi $s6, $s5, 9 #s6 is max player x
    	addi $s5, $s5, -4 #s5 is min player x
    	
    	#If the players x is greater than the max, or less than the min, branch
    	bgt $s1, $s6, pcc_next_iteration
    	blt $s1, $s5, pcc_next_iteration
    	
    	# Making it here means the player is within bounds. Set G to true and return
    	# also update the new achieved 'By' to the height of the platform
    	li $s5, 1
    	sb $s5, 8($s0) #G is true
    	lh $s5, 2($s3)
    	addi $s5, $s5, -10
    	sh $s5, 12($s0) # By is now this height 
    	
    	#If the platform is a trampoline, we also bounce the player, increasing Vy
    	lh $s5, 4($s3)
    	bne $s5, TRAMP_PLAT, pcc_not_trampoline
    	li $s5, TRAMP_BOUNCE
    	sh $s5, 4($s0)
    	
    pcc_not_trampoline:
    	jr $ra
    	
    	pcc_next_iteration:
    	    addi $s3, $s3, PLATFORM_SIZE
    	    addi $s4, $s4, 1
    	    bne $s4, NUM_PLATFORMS, pcc_check_platform_loop
    	
    	sb $zero, 8($s0) #G is false, no collision was found
    	jr $ra

# End of platform collision checking
# ------------------------------------------------- #

# ------- Camera Shifting Function ---------- #
# This function will check if the current max achieved Y is greater
# than the baseline value of CAMERA_HEIGHT. If it is it will shift the Y coordinate
# of everything on the screen down by CAMERA_SPEED pixels.

shift_camera_down:
	#First get the player so we can check if the camera needs to be shifted
	la $s0, player
	lh $s1, 12($s0) #Get By
	
	# If the camera is at the correct height, return to main
	bne $s1, CAMERA_HEIGHT, calc_camera_shift_amount
	jr $ra
	
    calc_camera_shift_amount:
    	li $s6, CAMERA_HEIGHT
	sub $s1, $s6, $s1 
	li $s7, CAMERA_SPEED
	# If the amount to shift is less than the speed of the camera, use that value instead
	bgt $s1, CAMERA_SPEED, shift_entities
	move $s7, $s1
    
    #Whenever a new type of on-screen entity is added, update this to shift them
    #Don't touch s7 in this time, it holds the shift amt, also, $s6 will hold the ra
    shift_entities:
    	move $s6, $ra
    	
	jal camera_shift_platforms
	jal camera_shift_player
	jal camera_shift_monster
	
	move $ra, $s6
	jr $ra
	
# End of camera shifting function	
# ------------------------------------------- #

# ---------- Platform Shifting Function -------- #
# Shift all platforms down by the offset stored in $s7
# If a platform goes offscreen (Y >= 60) then regenerate it at the top of the screen
# Make sure it generates in a reachable position, use the coord stored in t2

camera_shift_platforms:
	#Get the platforms addresses
	la $s0, platforms
	li $s1, 0
	
    camera_shift_platforms_loop:
    	#Get the current Y value and shift it down by the value in s7
    	lh $s2, 2($s0)
    	sh $s2, 10($s0) #update prev y
    	add $s2, $s2, $s7
    	
    	# Check that this new value isn't off screen, if it is, regenerate the platform
    	# at the top of the screen
    	
    	ble $s2, 60, csp_update_platform
    	
    	#Otherwise, generate a new platform
    	    #y
    	    li $s2, 2
    	    sh $s2, 2($s0) #Y
    	    #sh $s2, 10($s0) #Py
    	    
    	    #type
    	    li $v0, 42
    	    li $a0, 0
    	    li $a1, 3
    	    syscall
    	    sh $a0, 4($s0)
    	    
    	    #velocity
    	    li $s2, 0
    	    bne $a0, MOVING_PLAT, csp_not_moving 
    	    li $s2, PLAT_SPEED_R
    	    
    	    csp_not_moving:
    	    sh $s2, 6($s0)
    	    
    	    #x 
    	    addi $s2, $t2, -20 #min
    	    addi $s3, $t2, 20 #max
    	
    	    csp_fix_platform_min:
    	    bge $s2, MIN_PLAT_X, csp_fix_platform_max
    	    li $s2, MIN_PLAT_X 
    	 
    	    csp_fix_platform_max:
    	    ble $s3, MAX_PLAT_X, csp_generate_platform_value
    	    li $s3, MAX_PLAT_X 
    	
    	    csp_generate_platform_value:
    	    sub $a1, $s3, $s2 
    	
    	    #get our random number
    	    li $v0, 42
    	    li $a0, 0
    	    syscall
    	    
    	    add $s2, $s2, $a0
    	    move $t2, $s2
    	    
    	    sh $s2, 0($s0)
    	    #sh $s2, 8($s0)
    	    
    	    #now the platform is generated
    	    j csp_increment_platform
    	
    csp_update_platform:
    	sh $s2, 2($s0)
    
    csp_increment_platform:
    	addi $s0, $s0, PLATFORM_SIZE
    	addi $s1, $s1, 1
    	bne $s1, NUM_PLATFORMS, camera_shift_platforms_loop
    	
    jr $ra

# End of the platform shifting/regenerating function
# ---------------------------------------------- #

# ---------- Shift Player Function ---------- #
# This function is pretty simple, we just shift the player's Y coordinate
# by the amount stored in $s7, without touching $s6.

camera_shift_player:
	#update the y coordinate.
	la $s0, player
	lh $s1, 2($s0)
	add $s1, $s1, $s7
	sh $s1, 2($s0)
	
	#update the Best Y value
	lh $s1, 12($s0)
	add $s1, $s1, $s7
	sh $s1, 12($s0)
	
	jr $ra
# ------------------------------------------- # 

# ---------- Initialize Monsters ------------ #
# This function creates the monsters for the game.
# Intially Monsters cannot be seen, so we set A to 0.
# We could loop for this function, but its only two monmters
# so just init both manually.
init_monsters: 
	la $s0, monsters
	
	li $s1, 4 #Just use any value for X, will change on regen 
	li $s2, MON_ONE_Y #Load in the inital Y value
	
	#Store data in the struct
	sh $s1, 0($s0)
	sh $s2, 2($s0)
	sh $s1, 4($s0)
	sh $s2, 6($s0)
	sh $zero, 8($s0)
	
	addi $s0, $s0, MON_SIZE #Shift pointer to next monster
	li $s2, MON_TWO_Y
	
	#Store data in the struct
	sh $s1, 0($s0)
	sh $s2, 2($s0)
	sh $s1, 4($s0)
	sh $s2, 6($s0)
	sh $zero, 8($s0)
	
	jr $ra

# ------------------------------------------- #

# ---------- Update Monsters ---------------- #
# Update the previous coordinates of the monsters
# to match the current ones. 
update_monster_location:
	la $s0, monsters
	
	lh $s1, 0($s0)
	sh $s1, 4($s0)
	lh $s1, 2($s0)
	sh $s1, 6($s0)
	
	addi $s0, $s0, MON_SIZE
	
	lh $s1, 0($s0)
	sh $s1, 4($s0)
	lh $s1, 2($s0)
	sh $s1, 6($s0)
	
	jr $ra

# ------------------------------------------- #

# --------- Shift Monster Function ---------- #
# Shift and regen monsters without touching s6 or s7
camera_shift_monster:
	la $s0, monsters #get monster info
	li $s1, 0 #iterator
	
    csm_loop:
    	#Get the current Y value and shift it down by the value in s7
    	lh $s2, 2($s0)
    	sh $s2, 6($s0) #update prev y
    	add $s2, $s2, $s7 #update current y
    	
    	blt $s2, 56, csm_update
    	
    	#otherwise monster is considered out of bounds and needs to be regenerated.
    csm_regenerate_monster:
    	#y - set to -4 so that the monster appears one shift after the monster disappears.
    	# update the draw function not to draw/erase unless the monster is in bounds
    	li $s2, -4
    	sh $s2, 2($s0) #update the Y value
    	
    	#a - set alive to true, once the monster is offscreen it comes back to life
    	li $s2, 1
    	sh $s2, 8($s0)
    	
    	#x - generate a random x value within the range of the screen. (4 - 54)
	li $v0, 42 
	li $a0, 0
	li $a1, 50 
    	syscall
    	
    	addi $s2, $a0, MON_MIN_X #add the generated coord to the min value of X
    	sh $s2, 0($s0) #Save the new x coord
    	
    	j csm_iterate
    	
    csm_update:
    	sh $s2, 2($s0)
    
    csm_iterate:
    	addi $s0, $s0, MON_SIZE
    	addi $s1, $s1, 1
    	bne $s1, NUM_MONSTERS, csm_loop
    	
    	jr $ra
	
# ------------------------------------------- #

# --------- Draw Monster Function ----------- #
# Erase the monsters old position and redraw in
# the new spot.Only draw the monster if it is alive.

draw_monsters:
	la $s0, monsters #load in the monsters
	li $s1, 0 #iterator
	
    draw_monsters_loop:
    	# erase the old monster, load the values for Px and Py into a0, a1
    	# then store the ra in s7
    	move $s7, $ra
    	lh $a0, 4($s0)
    	lh $a1, 6($s0)
    	jal erase_monster_sprite
    	move $ra, $s7
    	
    	lh $s2, 8($s0) #we only draw the monster if its alive/inbounds otherwise go to the next one
    	bne $s2, 1, draw_monsters_iterate
    	lh $s2, 2($s0) #don't draw if monster is out of bounds
    	blt $s2, 2, draw_monsters_iterate 
    	
    	draw_monster_sprite:
    	#Load the colours and base address, then calc offset and paint it.
    	li $s2, BASE_ADDRESS
    	lh $s3, 0($s0)
    	sll $s3, $s3, 2
    	add $s2, $s2, $s3
    	lh $s3, 2($s0)
    	sll $s3, $s3, 8
    	add $s2, $s2, $s3 #this now holds the proper offset
    	
    	#load colors into s3 and s4
    	li $s3, MAIN_GREEN
    	li $s4, DARK_GREEN
    	
    	sw $s4, 0($s2) #row 1
	sw $s4, 16($s2)
	
	sw $s3, 256($s2) #row 2
	sw $s3, 260($s2)
	sw $s3, 264($s2)
	sw $s3, 268($s2)
	sw $s3, 272($s2)
	
	sw $s3, 512($s2) #row 3
	sw $s4, 516($s2)
	sw $s3, 520($s2)
	sw $s4, 524($s2)
	sw $s3, 528($s2)
	
	sw $s3, 768($s2) #row 4
	sw $s3, 772($s2)
	sw $s3, 776($s2)
	sw $s3, 780($s2)
	sw $s3, 784($s2)
	
	sw $s3, 1024($s2) #row 5
	sw $s4, 1028($s2)
	sw $s4, 1032($s2)
	sw $s4, 1036($s2)
	sw $s3, 1040($s2)
	
	sw $s3, 1280($s2) #row 6
	sw $s3, 1284($s2)
	sw $s3, 1288($s2)
	sw $s3, 1292($s2)
	sw $s3, 1296($s2)   	
    
    draw_monsters_iterate:
    	addi $s0, $s0, MON_SIZE
    	addi $s1, $s1, 1
    	bne $s1, NUM_MONSTERS, draw_monsters_loop
    	
    jr $ra

# ------------------------------------------- #

# --------- Erase Monster Function ---------- #
# Draw over the monsters old location with the bg color.
# Use the x and y stored in a0 and a1.

erase_monster_sprite:

    #Check that we aren't erasing something out of bounds
	bge $a1, 2, esm_erase 
	jr $ra
	
    esm_erase:
	li $s2, BASE_ADDRESS
	li $s3, BG_GREEN
	
	sll $a0, $a0, 2
	sll $a1, $a1, 8
	add $s2, $s2, $a0
	add $s2, $s2, $a1
	
	sw $s3, 0($s2) #row 1
	sw $s3, 16($s2)
	
	sw $s3, 256($s2) #row 2
	sw $s3, 260($s2)
	sw $s3, 264($s2)
	sw $s3, 268($s2)
	sw $s3, 272($s2)
	
	sw $s3, 512($s2) #row 3
	sw $s3, 516($s2)
	sw $s3, 520($s2)
	sw $s3, 524($s2)
	sw $s3, 528($s2)
	
	sw $s3, 768($s2) #row 4
	sw $s3, 772($s2)
	sw $s3, 776($s2)
	sw $s3, 780($s2)
	sw $s3, 784($s2)
	
	sw $s3, 1024($s2) #row 5
	sw $s3, 1028($s2)
	sw $s3, 1032($s2)
	sw $s3, 1036($s2)
	sw $s3, 1040($s2)
	
	sw $s3, 1280($s2) #row 6
	sw $s3, 1284($s2)
	sw $s3, 1288($s2)
	sw $s3, 1292($s2)
	sw $s3, 1296($s2)
	
	jr $ra

# ------------------------------------------- #

# ----- Init Bullets ------- #
init_bullets:
	la $s0, bullets #load in array
	li $s1, 0 #iterator
	
	sh $zero, 0($s0) #Current number of visible bullets is 0
	addi $s0, $s0, 2 #shift over to the first bullet struct
	
    init_bullet_loop:
    
   	#We can cheat and hide the bullets in a part of the screen
   	#where they can't be hit (X=2, Y=2)
	
	li $s2, BUL_DEF_XY #we can use this value for everything
	sh $s2, 0($s0)
	sh $s2, 2($s0)
	sh $s2, 4($s0)
	sh $s2, 6($s0)
	sh $zero, 8($s0) #not visible
	
	addi $s0, $s0, BUL_SIZE
	addi $s1, $s1, 1
	bne $s1, BUL_NUM, init_bullet_loop
	
	jr $ra
	
# -------------------------- #

# ------- Draw Bullets -------- #
# As the name implies, this function draws bullets
draw_bullets:
	la $s0, bullets #address of struct
	addi $s0, $s0, 2 #shift past num_vis
	li $s1, 0 #iterator
	
    db_loop:
    	#first erase the old bullets, pass Px, Py into a0, a1
    	#then save ra in s7
    	move $s7, $ra
    	lh $a0, 4($s0)
    	lh $a1, 6($s0)
    	jal erase_bullet
    	move $ra, $s7
    	
    	#If the bullet is not visible, we don't need to draw it
    	lh $s2, 8($s0)
    	bne $s2, 1, dbl_increment
    	
    	#If the bullet is visible, get its X and Y, calc the offset and draw the pixel
    	lh $s2, 0($s0)
    	lh $s3, 2($s0)
    	sll $s2, $s2, 2
    	sll $s3, $s3, 8
    	add $s3, $s2, $s3 #store total offset in $s3
    	
    	li $s2, BASE_ADDRESS
    	add $s2, $s2, $s3 #s2 now holds drawing address
    	
    	li $s3, DARK_GREEN #update the color to dark green
    	
    	sw $s3, 0($s2) #draw the sprite
    	
    	#increment
    dbl_increment: 
    	addi $s0, $s0, BUL_SIZE
    	addi $s1, $s1, 1
    	bne $s1, BUL_NUM, db_loop

	jr $ra
# ----------------------------- #

# -------- Erase Bullet -------- #
# Erases a bullet, noticeably easier because a bullet is a single pixel.
# values for x and y are in $a0, $a1.
erase_bullet: 
	li $s2, BASE_ADDRESS
	li $s3, BG_GREEN
	
	sll $a0, $a0, 2
	sll $a1, $a1, 8
	add $s2, $s2, $a0
	add $s2, $s2, $a1	
	
	#draw the pixel
	sw $s3, 0($s2)
	
	jr $ra
# ------------------------------ #

# ------- Spawn Bullet ---------- #
# If a player has clicked the button and there are less than 3 visible bullets
# then we need to move a currently non-visible bullet to the top of the player

spawn_bullet:
    #Check that the player is shooting
    la $s0, player
    lb $s0, 9($s0)
    
    #if player is shooting spawn the bullet, otherwise return
    beq $s0, 1, sb_player_shooting
    jr $ra
	
    sb_player_shooting:
	la $s0, bullets
	
	#update the number of bullets to x + 1
	lh $s1, 0($s0)
	addi $s1, $s1, 1
	sh $s1, 0($s0) 
	
	addi $s0, $s0, 2 #shift over to the actual bullet array
	li $s1, 0 #incrementor
	
    sb_loop:
    	#check if the bullet we are on is available - not visible
    	lh $s2, 8($s0)
    	beq $s2, 1, sb_increment #if visible, skip
    
    	#otherwise, get the players x and y and place the bullet accordingly.
    	la $s2, player
    	lh $s3, 0($s2) # x
    	lh $s4, 2($s2) # y
    	
    	addi $s3, $s3, 2 #spawn the bullet 2 pixels over
   	addi $s4, $s4, -1 #spawn the bullet 1 pixel above player
    
    sb_move_bullet:
    	sh $s3, 0($s0) #set the bullets position to the calculated coords
    	sh $s4, 2($s0)
    	
    	li $s4, 1 #
    	sh $s4, 8($s0) #set the bullet to be visible
    	
    	jr $ra #return early, as we have spawned a bullet
    
    sb_increment:
    	addi $s0, $s0, BUL_SIZE
    	addi $s1, $s1, 1
    	bne $s1, BUL_NUM, sb_loop
	
	jr $ra

# ------------------------------------ #

# ------ Stop Player Shooting ----- #
# Added a function to reset shooting value after the animation plays
# that way a player can tell they've shot a projectile
stop_player_shooting:
	la $s0, player
	sb $zero, 9($s0) #change shooting to false
	jr $ra
# --------------------------------- #

# --- Update Bullet Location ------ #
# Update the bullet locations by the BULLET SPEED Amount.
# If a bullet would go off the screen (upwards), we instead turn it invisible and put it back to the "hiding place"
update_bullet_location:
	la $s0, bullets
	addi $s0, $s0, 2 #shift to bullet structures
	li $s1, 0 #incrementor
	
    ubl_loop:
    	#If the bullet is not visible then there is no need to update its position.
    	lh $s2, 8($s0)
    	beq $s2, 0, ubl_increment
    	
    	#If the bullet is visible, then we update the previous location values first.
    	lh $s3, 0($s0)
    	lh $s4, 2($s0)
    	sh $s3, 4($s0)
    	sh $s4, 6($s0)
    	
    	#With that updated, we can then increment the y position by the BULLET SPEED
    	addi $s4, $s4, BUL_SPEED
    	
    	#Then we need to check if this puts the new Y value outside of the acceptable range.
    	bgt $s4, 2, ubl_update_pos
    	
    	#If outside of the acceptable range, we change this bullet to invisible and keep it in the hiding space
    	#We also need to update the total number of bullets to be one lower.
    	sh $zero, 8($s0)
    	li $s4, BUL_DEF_XY
    	sh $s4, 0($s0)
    	sh $s4, 2($s0)
    	
    	la $s4, bullets
    	lh $s5, 0($s4)
    	addi $s5, $s5, -1
    	sh $s5, 0($s4)
    	
    	j ubl_increment
    	
    ubl_update_pos:
    	sh $s4, 2($s0)
    
    ubl_increment:
    	addi $s0, $s0, BUL_SIZE
    	addi $s1, $s1, 1
    	bne $s1, BUL_NUM, ubl_loop
    
    jr $ra

# --------------------------------- #

# ------- Bullet Collision Detection ------ #
# Check if a shot bullet has collided with a monster.
# If it has, erase and reset the bullet, and change the monsters A -> 0

bullet_collision_check:
	la $s0, bullets
	addi $s0, $s0, 2
	li $s1, 0
	
	#could do a nested loop to check each bullet against each monster,
	#but there are only 2 monsters, so I will just check both monsters
	#manually
   bcc_loop:
   	lh $s2, 8($s0) #check bullet visiblity.
   	beq $s2, 0, bcc_iterate
   	
   	#Otherwise, check the x value of the bullet against the x value of monster one.
   	la $s2, monsters
   	lh $s2, 0($s2) #X - monster
   	lh $s3, 0($s0) #X - bullet
   	
      	#is bullet X less than monster x?
        bcc_check_left_one:
   	    blt $s3, $s2, bcc_check_monster_two
        
        #is bullet X more than monster x?
        bcc_check_right_one:
    	    addi $s2, $s2, 5
    	    bgt $s3, $s2, bcc_check_monster_two
    	    
    	#Making it here means that the x is in the correct range for the monster
    	#Now we check the Y for the same thing.
    	la $s2, monsters
   	lh $s2, 2($s2) #X - monster
   	lh $s3, 2($s0) #X - bullet
    	   
    	#is bullet y less than monster y?     
        bcc_check_top_one:
   	    blt $s3, $s2, bcc_check_monster_two
        
        #is bullet y less than monster y?
        bcc_check_bot_one:
    	    addi $s2, $s2, 6
    	    bgt $s3, $s2, bcc_check_monster_two
    	    
    	#If we made it here, then the bullet is hitting monster one.
    	#Set the monster to dead, and then set the bullet to default position.
    	#Don't forget to update the number of bullets
    	
    	#set monster to dead
    	la $s2, monsters
    	sh $zero, 8($s2)
    	
    	#decrement # of bullets
    	la $s2, bullets
    	lh $s3, 0($s2)
    	addi $s3, $s3, -1
    	sh $s3, 0($s2)
    	
    	#Reset current bullet with default pos and info.
    	li $s2, BUL_DEF_XY
    	sh $s2, 0($s0)
    	sh $s2, 2($s0)
    	sh $zero, 8($s0)
    	
    	j bcc_iterate #can't have overlapping monsters, so save some time.
    	
    bcc_check_monster_two:
    	
    	la $s2, monsters
   	lh $s2, 10($s2) #X - monster
   	lh $s3, 0($s0) #X - bullet
   	
      	#is bullet X less than monster x?
        bcc_check_left_two:
   	    blt $s3, $s2, bcc_iterate
        
        #is bullet X more than monster x?
        bcc_check_right_two:
    	    addi $s2, $s2, 5
    	    bgt $s3, $s2, bcc_iterate
    	    
    	#Making it here means that the x is in the correct range for the monster
    	#Now we check the Y for the same thing.
    	la $s2, monsters
   	lh $s2, 12($s2) #X - monster
   	lh $s3, 2($s0) #X - bullet
    	   
    	#is bullet y less than monster y?     
        bcc_check_top_two:
   	    blt $s3, $s2, bcc_iterate
        
        #is bullet y less than monster y?
        bcc_check_bot_two:
    	    addi $s2, $s2, 6
    	    bgt $s3, $s2, bcc_iterate
    	
    	#If we made it here, then the bullet is hitting monster two.
    	#Set the monster to dead, and then set the bullet to default position.
    	#Don't forget to update the number of bullets
    	
    	la $s2, monsters
    	sh $zero, 18($s2)
    	
    	#decrement # of bullets
    	la $s2, bullets
    	lh $s3, 0($s2)
    	addi $s3, $s3, -1
    	sh $s3, 0($s2)
    	
	#Reset current bullet with default pos and info.
    	li $s2, BUL_DEF_XY
    	sh $s2, 0($s0)
    	sh $s2, 2($s0)
    	sh $zero, 8($s0)
    	
    bcc_iterate:
   	addi $s0, $s0, BUL_SIZE
   	addi $s1, $s1, 1
   	bne $s1, BUL_NUM, bcc_loop
   	
   	jr $ra

# ----------------------------------------- #

# ---------- Check Loss ---------- #
# Check the two conditions, either we hit a monster or we hit the bottom of the screen, both mean we lost.
check_game_loss:
	la $s0, player #load the player
	lh $s1, 2($s0) #hit bottom of screen
	lh $s2, 14($s0) #hit monster

	bge $s1, 52, end_game
	beq $s2, 1, end_game 

	#otherwise, keep the game going
	jr $ra	
	
    end_game:
    	j game_over_loop
	
# -------------------------------- #

# -------- Game Over Loop -------- #
# When we enter the game over state, we draw the final screen
# and then wait for the play to click p to restart.

game_over_loop:
	#start by drawing the game over screen
	li $s0, BASE_ADDRESS
	li $s1, GAME_OVER_X
	li $s2, GAME_OVER_Y
	sll $s1, $s1, 2
	sll $s2, $s2, 8
	add $s0, $s0, $s1
	add $s0, $s0, $s2 #calculate displacement
	
	#Draw the game over:
	li $s2, MAIN_GREEN
	li $s3, DARK_GREEN
	
	sw $s2, 0($s0) #row 1
	sw $s2, 4($s0)
	sw $s2, 8($s0)
	sw $s2, 12($s0)
	sw $s2, 16($s0)
	sw $s2, 20($s0)
	sw $s2, 24($s0)
	sw $s2, 28($s0)
	sw $s2, 32($s0)
	sw $s2, 36($s0)
	sw $s2, 40($s0)
	sw $s2, 44($s0)
	sw $s2, 48($s0)
	sw $s2, 52($s0)
	sw $s2, 56($s0)
	sw $s2, 60($s0)
	sw $s2, 64($s0)
	sw $s2, 68($s0)
	sw $s2, 72($s0)
	sw $s2, 76($s0)
	sw $s2, 80($s0)
	sw $s2, 84($s0)
	sw $s2, 88($s0)
	sw $s2, 92($s0)
	
	sw $s2, 256($s0) #row 2
	sw $s2, 260($s0)
	sw $s3, 264($s0)
	sw $s3, 268($s0)
	sw $s3, 272($s0)
	sw $s2, 276($s0)
	sw $s2, 280($s0)
	sw $s2, 284($s0)
	sw $s2, 288($s0)
	sw $s2, 292($s0)
	sw $s2, 296($s0)
	sw $s2, 300($s0)
	sw $s2, 304($s0)
	sw $s2, 308($s0)
	sw $s2, 312($s0)
	sw $s2, 316($s0)
	sw $s2, 320($s0)
	sw $s2, 324($s0)
	sw $s2, 328($s0)
	sw $s2, 332($s0)
	sw $s2, 336($s0)
	sw $s2, 340($s0)
	sw $s2, 344($s0)
	sw $s2, 348($s0)
	
	sw $s2, 512($s0) #row 3
	sw $s3, 516($s0)
	sw $s2, 520($s0)
	sw $s2, 524($s0)
	sw $s2, 528($s0)
	sw $s3, 532($s0)
	sw $s2, 536($s0)
	sw $s3, 540($s0)
	sw $s3, 544($s0)
	sw $s3, 548($s0)
	sw $s2, 552($s0)
	sw $s2, 556($s0)
	sw $s3, 560($s0)
	sw $s3, 564($s0)
	sw $s2, 568($s0)
	sw $s3, 572($s0)
	sw $s2, 576($s0)
	sw $s2, 580($s0)
	sw $s2, 584($s0)
	sw $s3, 588($s0)
	sw $s3, 592($s0)
	sw $s2, 596($s0)
	sw $s2, 600($s0)
	sw $s2, 604($s0)
	
	sw $s2, 768($s0) #row 4
	sw $s3, 772($s0)
	sw $s2, 776($s0)
	sw $s2, 780($s0)
	sw $s2, 784($s0)
	sw $s2, 788($s0)
	sw $s2, 792($s0)
	sw $s2, 796($s0)
	sw $s2, 800($s0)
	sw $s2, 804($s0)
	sw $s3, 808($s0)
	sw $s2, 812($s0)
	sw $s3, 816($s0)
	sw $s2, 820($s0)
	sw $s3, 824($s0)
	sw $s2, 828($s0)
	sw $s3, 832($s0)
	sw $s2, 836($s0)
	sw $s3, 840($s0)
	sw $s2, 844($s0)
	sw $s2, 848($s0)
	sw $s3, 852($s0)
	sw $s2, 856($s0)
	sw $s2, 860($s0)
	
	sw $s2, 1024($s0) #row 5
	sw $s3, 1028($s0)
	sw $s2, 1032($s0)	
	sw $s2, 1036($s0)
	sw $s3, 1040($s0)
	sw $s3, 1044($s0)
	sw $s2, 1048($s0)
	sw $s2, 1052($s0)
	sw $s3, 1056($s0)
	sw $s3, 1060($s0)
	sw $s3, 1064($s0)
	sw $s2, 1068($s0)
	sw $s3, 1072($s0)
	sw $s2, 1076($s0)
	sw $s3, 1080($s0)
	sw $s2, 1084($s0)
	sw $s3, 1088($s0)
	sw $s2, 1092($s0)
	sw $s3, 1096($s0)
	sw $s3, 1100($s0)
	sw $s3, 1104($s0)
	sw $s3, 1108($s0)
	sw $s2, 1112($s0)
	sw $s2, 1116($s0)
	
	sw $s2, 1280($s0) #row 6
	sw $s3, 1284($s0)
	sw $s2, 1288($s0)
	sw $s2, 1292($s0)
	sw $s2, 1296($s0)
	sw $s3, 1300($s0)
	sw $s2, 1304($s0)
	sw $s3, 1308($s0)
	sw $s2, 1312($s0)
	sw $s2, 1316($s0)
	sw $s3, 1320($s0)
	sw $s2, 1324($s0)
	sw $s3, 1328($s0)
	sw $s2, 1332($s0)
	sw $s3, 1336($s0)
	sw $s2, 1340($s0)
	sw $s3, 1344($s0)
	sw $s2, 1348($s0)
	sw $s3, 1352($s0)
	sw $s2, 1356($s0)
	sw $s2, 1360($s0)
	sw $s2, 1364($s0)
	sw $s2, 1368($s0)
	sw $s2, 1372($s0)
	
	sw $s2, 1536($s0) #row 7
	sw $s2, 1540($s0)
	sw $s3, 1544($s0)
	sw $s3, 1548($s0)
	sw $s3, 1552($s0)
	sw $s2, 1556($s0)
	sw $s2, 1560($s0)
	sw $s2, 1564($s0)
	sw $s3, 1568($s0)
	sw $s3, 1572($s0)
	sw $s3, 1576($s0)
	sw $s2, 1580($s0)
	sw $s3, 1584($s0)
	sw $s2, 1588($s0)
	sw $s3, 1592($s0)
	sw $s2, 1596($s0)
	sw $s3, 1600($s0)
	sw $s2, 1604($s0)
	sw $s2, 1608($s0)
	sw $s3, 1612($s0)
	sw $s3, 1616($s0)
	sw $s3, 1620($s0)
	sw $s2, 1624($s0)
	sw $s2, 1628($s0)
	
	sw $s2, 1792($s0) #row 8
	sw $s2, 1796($s0)
	sw $s2, 1800($s0)
	sw $s2, 1804($s0)
	sw $s2, 1808($s0)
	sw $s2, 1812($s0)
	sw $s2, 1816($s0)
	sw $s2, 1820($s0)
	sw $s2, 1824($s0)
	sw $s2, 1828($s0)
	sw $s2, 1832($s0)
	sw $s2, 1836($s0)
	sw $s2, 1840($s0)
	sw $s2, 1844($s0)
	sw $s2, 1848($s0)
	sw $s2, 1852($s0)
	sw $s2, 1856($s0)
	sw $s2, 1860($s0)
	sw $s2, 1864($s0)
	sw $s2, 1868($s0)
	sw $s2, 1872($s0)
	sw $s2, 1876($s0)
	sw $s2, 1880($s0)
	sw $s2, 1884($s0)
	
	sw $s2, 2048($s0) #row 9
	sw $s2, 2052($s0)
	sw $s2, 2056($s0)
	sw $s2, 2060($s0)
	sw $s2, 2064($s0)
	sw $s2, 2068($s0)
	sw $s2, 2072($s0)
	sw $s2, 2076($s0)
	sw $s2, 2080($s0)
	sw $s2, 2084($s0)
	sw $s2, 2088($s0)
	sw $s2, 2092($s0)
	sw $s2, 2096($s0)
	sw $s2, 2100($s0)
	sw $s2, 2104($s0)
	sw $s2, 2108($s0)
	sw $s2, 2112($s0)
	sw $s2, 2116($s0)
	sw $s2, 2120($s0)
	sw $s2, 2124($s0)
	sw $s2, 2128($s0)
	sw $s2, 2132($s0)
	sw $s2, 2136($s0)
	sw $s2, 2140($s0)
	
	sw $s2, 2304($s0)  #row 10
	sw $s2, 2308($s0)
	sw $s2, 2312($s0)
	sw $s2, 2316($s0)
	sw $s3, 2320($s0)
	sw $s3, 2324($s0)
	sw $s3, 2328($s0)
	sw $s2, 2332($s0)
	sw $s2, 2336($s0)
	sw $s2, 2340($s0)
	sw $s2, 2344($s0)
	sw $s2, 2348($s0)
	sw $s2, 2352($s0)
	sw $s2, 2356($s0)
	sw $s2, 2360($s0)
	sw $s2, 2364($s0)
	sw $s2, 2368($s0)
	sw $s2, 2372($s0)
	sw $s2, 2376($s0)
	sw $s2, 2380($s0)
	sw $s2, 2384($s0)
	sw $s2, 2388($s0)
	sw $s2, 2392($s0)
	sw $s2, 2396($s0)
	
	sw $s2, 2560($s0) #row 11
	sw $s2, 2564($s0)
	sw $s2, 2568($s0)
	sw $s3, 2572($s0)
	sw $s2, 2576($s0)
	sw $s2, 2580($s0)
	sw $s2, 2584($s0)
	sw $s3, 2588($s0)
	sw $s2, 2592($s0)
	sw $s3, 2596($s0)
	sw $s2, 2600($s0)
	sw $s2, 2604($s0)
	sw $s3, 2608($s0)
	sw $s2, 2612($s0)
	sw $s2, 2616($s0)
	sw $s3, 2620($s0)
	sw $s3, 2624($s0)
	sw $s2, 2628($s0)
	sw $s2, 2632($s0)
	sw $s3, 2636($s0)
	sw $s2, 2640($s0)
	sw $s2, 2644($s0)
	sw $s2, 2648($s0)
	sw $s2, 2652($s0)
	
	sw $s2, 2816($s0) #row 12
	sw $s2, 2820($s0)
	sw $s2, 2824($s0)
	sw $s3, 2828($s0)
	sw $s2, 2832($s0)
	sw $s2, 2836($s0)
	sw $s2, 2840($s0)
	sw $s3, 2844($s0)
	sw $s2, 2848($s0)
	sw $s3, 2852($s0)
	sw $s2, 2856($s0)
	sw $s2, 2860($s0)
	sw $s3, 2864($s0)
	sw $s2, 2868($s0)
	sw $s3, 2872($s0)
	sw $s2, 2876($s0)
	sw $s2, 2880($s0)
	sw $s3, 2884($s0)
	sw $s2, 2888($s0)
	sw $s3, 2892($s0)
	sw $s3, 2896($s0)
	sw $s3, 2900($s0)
	sw $s2, 2904($s0)
	sw $s2, 2908($s0)
	
	sw $s2, 3072($s0) #row 13
	sw $s2, 3076($s0)
	sw $s2, 3080($s0)
	sw $s3, 3084($s0)
	sw $s2, 3088($s0)
	sw $s2, 3092($s0)
	sw $s2, 3096($s0)
	sw $s3, 3100($s0)
	sw $s2, 3104($s0)
	sw $s3, 3108($s0)
	sw $s2, 3112($s0)
	sw $s2, 3116($s0)
	sw $s3, 3120($s0)
	sw $s2, 3124($s0)
	sw $s3, 3128($s0)
	sw $s3, 3132($s0)
	sw $s3, 3136($s0)
	sw $s3, 3140($s0)
	sw $s2, 3144($s0)
	sw $s3, 3148($s0)
	sw $s2, 3152($s0)
	sw $s2, 3156($s0)
	sw $s3, 3160($s0)
	sw $s2, 3164($s0)
	
	sw $s2, 3328($s0) #row 14
	sw $s2, 3332($s0)
	sw $s2, 3336($s0)
	sw $s3, 3340($s0)
	sw $s2, 3344($s0)
	sw $s2, 3348($s0)
	sw $s2, 3352($s0)
	sw $s3, 3356($s0)
	sw $s2, 3360($s0)
	sw $s3, 3364($s0)
	sw $s2, 3368($s0)
	sw $s2, 3372($s0)
	sw $s3, 3376($s0)
	sw $s2, 3380($s0)
	sw $s3, 3384($s0)
	sw $s2, 3388($s0)
	sw $s2, 3392($s0)
	sw $s2, 3396($s0)
	sw $s2, 3400($s0)
	sw $s3, 3404($s0)
	sw $s2, 3408($s0)
	sw $s2, 3412($s0)
	sw $s2, 3416($s0)
	sw $s2, 3420($s0)
	
	sw $s2, 3584($s0) #row 15
	sw $s2, 3588($s0)
	sw $s2, 3592($s0)
	sw $s2, 3596($s0)
	sw $s3, 3600($s0)
	sw $s3, 3604($s0)
	sw $s3, 3608($s0)
	sw $s2, 3612($s0)
	sw $s2, 3616($s0)
	sw $s2, 3620($s0)
	sw $s3, 3624($s0)
	sw $s3, 3628($s0)
	sw $s2, 3632($s0)
	sw $s2, 3636($s0)
	sw $s2, 3640($s0)
	sw $s3, 3644($s0)
	sw $s3, 3648($s0)
	sw $s3, 3652($s0)
	sw $s2, 3656($s0)
	sw $s3, 3660($s0)
	sw $s2, 3664($s0)
	sw $s2, 3668($s0)
	sw $s2, 3672($s0)
	sw $s2, 3676($s0)
	
	sw $s2, 3840($s0) #row 16
	sw $s2, 3844($s0)
	sw $s2, 3848($s0)
	sw $s2, 3852($s0)
	sw $s2, 3856($s0)
	sw $s2, 3860($s0)
	sw $s2, 3864($s0)
	sw $s2, 3868($s0)
	sw $s2, 3872($s0)
	sw $s2, 3876($s0)
	sw $s2, 3880($s0)
	sw $s2, 3884($s0)
	sw $s2, 3888($s0)
	sw $s2, 3892($s0)
	sw $s2, 3896($s0)
	sw $s2, 3900($s0)
	sw $s2, 3904($s0)
	sw $s2, 3908($s0)
	sw $s2, 3912($s0)
	sw $s2, 3916($s0)
	sw $s2, 3920($s0)
	sw $s2, 3924($s0)
	sw $s2, 3928($s0)
	sw $s2, 3932($s0)
	
	#With the game over drawn we now enter a loop, waiting for the player to restart the game
	#This is done of course by pressing p.
    gol_wait_for_reset:
    	li $t9, KEYPRESS_ADDRESS
	lw $t8, 0($t9)
	bne $t8, 1, gol_wait_for_reset
	
	#If a key was pressed, make sure it was p, otherwise ignore
	lw $t8, 4($t9)
	bne $t8, 0x70, gol_wait_for_reset

	#Restart the game and re-initialize everything.
	j start_game
	
# -------------------------------- #

# ---------- Check Monster Collision ------- #
# This function will check if a player is overlapping with a monster
# If the player is overlapping, it sets the dead value to true
# this will make the game end after the next drawing of the loop.

# We will iterate over the monsters and if either one is overlapping then 
# we kill the player
monster_collision_check:
	la $s0, monsters
	li $s1, 0 #iterator
	
    mcc_loop: 
    	#If the monster is dead we can just skip it
    	lh $s2, 8($s0)
    	beq $s2, 0, mcc_iterate
    	
    	#If the monster is alive, then check if the y coordinates align.
    mcc_check_y:
    	la $s2, player #load in the player
    	lh $s3, 2($s2) #store player Y value
    	lh $s4, 2($s0) #store monster Y value
    	
    	addi $s5, $s4, 5 #set s5 to be upper bound
    	addi $s4, $s4, -9 #set s4 to be lower bound
    	
    	bgt $s3, $s5, mcc_iterate #skip to next monster, player is below monster
    	blt $s3, $s4, mcc_iterate #skip to next monster, player is above monster
    	
    	#Now we need to confirm the X
    	lh $s3, 0($s2) #store player X value
    	lh $s4, 0($s0) #store monster X value
    	
    	addi $s5, $s4, 4 #set s5 to be upper bound
    	addi $s4, $s4, -4 #set s4 to be lower bound
    	
    	bgt $s3, $s5, mcc_iterate #skip to next monster, player is right of monster
    	blt $s3, $s4, mcc_iterate #skip to next monster, player is left of monster
    	
    	#If we get here, then we confirm the player and the monster are overlapping, so
    	#we set the player to dead.
    	
    	li $s3, 1
    	sh $s3, 14($s2) #update the dead value of the player to true
    	    	
    mcc_iterate:
    	addi $s0, $s0, MON_SIZE
    	addi $s1, $s1, 1
    	bne $s1, NUM_MONSTERS, mcc_loop
    	
    jr $ra

# ------------------------------------------ #

# -------- Init Scoreboard -------- #
# Init the scoreboard and set everything to zero

init_scoreboard:
	la $s0, scoreboard
	sh $zero, 0($s0) #total
	sh $zero, 2($s0) #tens
	sh $zero, 4($s0) #ones
	jr $ra

#---------------------------------- # 

# ------- Update Scoreboard -------- #
# Increment the scoreboard by one, also perform some shenanigans
# for the tens and ones values

update_scoreboard:

    #We only update the scoreboard when the player reaches a best Y of 15
    #This means reaching a new highest platform. 
    
    	#load in the player and return if the best Y is not 15
    	la $s0, player
    	lh $s0, 12($s0)
    	ble $s0, SB_BY, us_update_total
    	jr $ra	

    us_update_total:
    	la $s0, scoreboard	
	lh $s1, 0($s0) #load the total score
	addi $s1, $s1, 1 #increment by one
	sh $s1, 0($s0) #update the scoreboard
	
    us_update_ones:
	lh $s1, 4($s0) #load the ones column
	addi $s1, $s1, 1 #increment by one.
	
	beq $s1, 10, us_update_tens #if the value becomes 10 branch
	sh $s1, 4($s0) #save the new value
	jr $ra #otherwise we are done there.
    
    us_update_tens:
    	#start by setting the ones back to 0
    	sh $zero, 4($s0)
    	lh $s1, 2($s0) #then load in the 10s
	addi $s1, $s1, 1 #increment by 1
	sh $s1, 2($s0) #write it back
	jr $ra
	
# ---------------------------------- #

# --------- Draw Scoreboard -------- #
# Draw the scoreboard. This uses a lot of helper functions to work.

draw_scoreboard:
	#Don't need an erasing function for this becasue awe just draw on top of the old digits.
	la $s0, scoreboard
	
	#set the base address to the correct position to draw the 10s
	li $s1, BASE_ADDRESS
	li $s2, SB_X
	li $s3, SB_Y
	sll $s2, $s2, 2
	sll $s3, $s3, 8
	add $s1, $s1, $s2
	add $s1, $s1, $s3 
	
	#load base address into a0, 10s value into a1 and call draw number
	#store the pc in s7
	move $a0, $s1
	lh $a1, 2($s0)
	move $s7, $ra
	jal draw_number
	move $ra, $s7
	
	#Shift the base address over to the ones position
	addi $s1, $s1, 20
	
	#load base address into a0, 1s value into a1 and call draw number
	#store the pc in s7
	move $a0, $s1
	lh $a1, 4($s0)
	move $s7, $ra
	jal draw_number
	move $ra, $s7
	
	jr $ra
# ---------------------------------- #

# -------------- Number Drawing Helper Function ------ #
#Draws the number in a1 at the location a0, we use s5 and s6 for colors
draw_number:
	li $s5, DARK_GREEN
	li $s6, WHITE

	beq $a1, 0, dn_zero
	beq $a1, 1, dn_one
	beq $a1, 2, dn_two
	beq $a1, 3, dn_three
	beq $a1, 4, dn_four
	beq $a1, 5, dn_five
	beq $a1, 6, dn_six
	beq $a1, 7, dn_seven
	beq $a1, 8, dn_eight
	beq $a1, 9, dn_nine
	
	jr $ra #if for some reason the number didn't match, dont draw
	
    dn_zero: 
    	sw $s5, 0($a0)
    	sw $s5, 4($a0)
	sw $s5, 8($a0)
	sw $s5, 12($a0)
	sw $s5, 16($a0)
	
	sw $s5, 256($a0)
    	sw $s6, 260($a0)
	sw $s6, 264($a0)
	sw $s6, 268($a0)
	sw $s5, 272($a0)
	
	sw $s5, 512($a0)
    	sw $s6, 516($a0)
	sw $s5, 520($a0)
	sw $s6, 524($a0)
	sw $s5, 528($a0)
	
	sw $s5, 768($a0)
    	sw $s6, 772($a0)
	sw $s5, 776($a0)
	sw $s6, 780($a0)
	sw $s5, 784($a0)
	
	sw $s5, 1024($a0)
    	sw $s6, 1028($a0)
	sw $s5, 1032($a0)
	sw $s6, 1036($a0)
	sw $s5, 1040($a0)
	
	sw $s5, 1280($a0)
    	sw $s6, 1284($a0)
	sw $s6, 1288($a0)
	sw $s6, 1292($a0)
	sw $s5, 1296($a0)
	
	sw $s5, 1536($a0)
    	sw $s5, 1540($a0)
	sw $s5, 1544($a0)
	sw $s5, 1548($a0)
	sw $s5, 1552($a0)
	
	jr $ra
	
    dn_one: 
    	sw $s5, 0($a0)
    	sw $s5, 4($a0)
	sw $s5, 8($a0)
	sw $s5, 12($a0)
	sw $s5, 16($a0)
	
	sw $s5, 256($a0)
    	sw $s5, 260($a0)
	sw $s5, 264($a0)
	sw $s6, 268($a0)
	sw $s5, 272($a0)
	
	sw $s5, 512($a0)
    	sw $s5, 516($a0)
	sw $s5, 520($a0)
	sw $s6, 524($a0)
	sw $s5, 528($a0)
	
	sw $s5, 768($a0)
    	sw $s5, 772($a0)
	sw $s5, 776($a0)
	sw $s6, 780($a0)
	sw $s5, 784($a0)
	
	sw $s5, 1024($a0)
    	sw $s5, 1028($a0)
	sw $s5, 1032($a0)
	sw $s6, 1036($a0)
	sw $s5, 1040($a0)
	
	sw $s5, 1280($a0)
    	sw $s5, 1284($a0)
	sw $s5, 1288($a0)
	sw $s6, 1292($a0)
	sw $s5, 1296($a0)
	
	sw $s5, 1536($a0)
    	sw $s5, 1540($a0)
	sw $s5, 1544($a0)
	sw $s5, 1548($a0)
	sw $s5, 1552($a0)
	
	jr $ra
	
    dn_two: 
    	sw $s5, 0($a0)
    	sw $s5, 4($a0)
	sw $s5, 8($a0)
	sw $s5, 12($a0)
	sw $s5, 16($a0)
	
	sw $s5, 256($a0)
    	sw $s6, 260($a0)
	sw $s6, 264($a0)
	sw $s6, 268($a0)
	sw $s5, 272($a0)
	
	sw $s5, 512($a0)
    	sw $s5, 516($a0)
	sw $s5, 520($a0)
	sw $s6, 524($a0)
	sw $s5, 528($a0)
	
	sw $s5, 768($a0)
    	sw $s6, 772($a0)
	sw $s6, 776($a0)
	sw $s6, 780($a0)
	sw $s5, 784($a0)
	
	sw $s5, 1024($a0)
    	sw $s6, 1028($a0)
	sw $s5, 1032($a0)
	sw $s5, 1036($a0)
	sw $s5, 1040($a0)
	
	sw $s5, 1280($a0)
    	sw $s6, 1284($a0)
	sw $s6, 1288($a0)
	sw $s6, 1292($a0)
	sw $s5, 1296($a0)
	
	sw $s5, 1536($a0)
    	sw $s5, 1540($a0)
	sw $s5, 1544($a0)
	sw $s5, 1548($a0)
	sw $s5, 1552($a0)
	
	jr $ra
	
    dn_three: 
    	sw $s5, 0($a0)
    	sw $s5, 4($a0)
	sw $s5, 8($a0)
	sw $s5, 12($a0)
	sw $s5, 16($a0)
	
	sw $s5, 256($a0)
    	sw $s6, 260($a0)
	sw $s6, 264($a0)
	sw $s6, 268($a0)
	sw $s5, 272($a0)
	
	sw $s5, 512($a0)
    	sw $s5, 516($a0)
	sw $s5, 520($a0)
	sw $s6, 524($a0)
	sw $s5, 528($a0)
	
	sw $s5, 768($a0)
    	sw $s5, 772($a0)
	sw $s6, 776($a0)
	sw $s6, 780($a0)
	sw $s5, 784($a0)
	
	sw $s5, 1024($a0)
    	sw $s5, 1028($a0)
	sw $s5, 1032($a0)
	sw $s6, 1036($a0)
	sw $s5, 1040($a0)
	
	sw $s5, 1280($a0)
    	sw $s6, 1284($a0)
	sw $s6, 1288($a0)
	sw $s6, 1292($a0)
	sw $s5, 1296($a0)
	
	sw $s5, 1536($a0)
    	sw $s5, 1540($a0)
	sw $s5, 1544($a0)
	sw $s5, 1548($a0)
	sw $s5, 1552($a0)
	
	jr $ra

    dn_four: 
    	sw $s5, 0($a0)
    	sw $s5, 4($a0)
	sw $s5, 8($a0)
	sw $s5, 12($a0)
	sw $s5, 16($a0)
	
	sw $s5, 256($a0)
    	sw $s6, 260($a0)
	sw $s5, 264($a0)
	sw $s6, 268($a0)
	sw $s5, 272($a0)
	
	sw $s5, 512($a0)
    	sw $s6, 516($a0)
	sw $s5, 520($a0)
	sw $s6, 524($a0)
	sw $s5, 528($a0)
	
	sw $s5, 768($a0)
    	sw $s6, 772($a0)
	sw $s6, 776($a0)
	sw $s6, 780($a0)
	sw $s5, 784($a0)
	
	sw $s5, 1024($a0)
    	sw $s5, 1028($a0)
	sw $s5, 1032($a0)
	sw $s6, 1036($a0)
	sw $s5, 1040($a0)
	
	sw $s5, 1280($a0)
    	sw $s5, 1284($a0)
	sw $s5, 1288($a0)
	sw $s6, 1292($a0)
	sw $s5, 1296($a0)
	
	sw $s5, 1536($a0)
    	sw $s5, 1540($a0)
	sw $s5, 1544($a0)
	sw $s5, 1548($a0)
	sw $s5, 1552($a0)
	
	jr $ra

    dn_five: 
    	sw $s5, 0($a0)
    	sw $s5, 4($a0)
	sw $s5, 8($a0)
	sw $s5, 12($a0)
	sw $s5, 16($a0)
	
	sw $s5, 256($a0)
    	sw $s6, 260($a0)
	sw $s6, 264($a0)
	sw $s6, 268($a0)
	sw $s5, 272($a0)
	
	sw $s5, 512($a0)
    	sw $s6, 516($a0)
	sw $s5, 520($a0)
	sw $s5, 524($a0)
	sw $s5, 528($a0)
	
	sw $s5, 768($a0)
    	sw $s6, 772($a0)
	sw $s6, 776($a0)
	sw $s6, 780($a0)
	sw $s5, 784($a0)
	
	sw $s5, 1024($a0)
    	sw $s5, 1028($a0)
	sw $s5, 1032($a0)
	sw $s6, 1036($a0)
	sw $s5, 1040($a0)
	
	sw $s5, 1280($a0)
    	sw $s6, 1284($a0)
	sw $s6, 1288($a0)
	sw $s6, 1292($a0)
	sw $s5, 1296($a0)
	
	sw $s5, 1536($a0)
    	sw $s5, 1540($a0)
	sw $s5, 1544($a0)
	sw $s5, 1548($a0)
	sw $s5, 1552($a0)
	
	jr $ra
	
    dn_six: 
    	sw $s5, 0($a0)
    	sw $s5, 4($a0)
	sw $s5, 8($a0)
	sw $s5, 12($a0)
	sw $s5, 16($a0)
	
	sw $s5, 256($a0)
    	sw $s6, 260($a0)
	sw $s6, 264($a0)
	sw $s6, 268($a0)
	sw $s5, 272($a0)
	
	sw $s5, 512($a0)
    	sw $s6, 516($a0)
	sw $s5, 520($a0)
	sw $s5, 524($a0)
	sw $s5, 528($a0)
	
	sw $s5, 768($a0)
    	sw $s6, 772($a0)
	sw $s6, 776($a0)
	sw $s6, 780($a0)
	sw $s5, 784($a0)
	
	sw $s5, 1024($a0)
    	sw $s6, 1028($a0)
	sw $s5, 1032($a0)
	sw $s6, 1036($a0)
	sw $s5, 1040($a0)
	
	sw $s5, 1280($a0)
    	sw $s6, 1284($a0)
	sw $s6, 1288($a0)
	sw $s6, 1292($a0)
	sw $s5, 1296($a0)
	
	sw $s5, 1536($a0)
    	sw $s5, 1540($a0)
	sw $s5, 1544($a0)
	sw $s5, 1548($a0)
	sw $s5, 1552($a0)
	
	jr $ra
	
    dn_seven: 
    	sw $s5, 0($a0)
    	sw $s5, 4($a0)
	sw $s5, 8($a0)
	sw $s5, 12($a0)
	sw $s5, 16($a0)
	
	sw $s5, 256($a0)
    	sw $s6, 260($a0)
	sw $s6, 264($a0)
	sw $s6, 268($a0)
	sw $s5, 272($a0)
	
	sw $s5, 512($a0)
    	sw $s5, 516($a0)
	sw $s5, 520($a0)
	sw $s6, 524($a0)
	sw $s5, 528($a0)
	
	sw $s5, 768($a0)
    	sw $s5, 772($a0)
	sw $s5, 776($a0)
	sw $s6, 780($a0)
	sw $s5, 784($a0)
	
	sw $s5, 1024($a0)
    	sw $s5, 1028($a0)
	sw $s5, 1032($a0)
	sw $s6, 1036($a0)
	sw $s5, 1040($a0)
	
	sw $s5, 1280($a0)
    	sw $s5, 1284($a0)
	sw $s5, 1288($a0)
	sw $s6, 1292($a0)
	sw $s5, 1296($a0)
	
	sw $s5, 1536($a0)
    	sw $s5, 1540($a0)
	sw $s5, 1544($a0)
	sw $s5, 1548($a0)
	sw $s5, 1552($a0)
	
	jr $ra
	
    dn_eight: 
    	sw $s5, 0($a0)
    	sw $s5, 4($a0)
	sw $s5, 8($a0)
	sw $s5, 12($a0)
	sw $s5, 16($a0)
	
	sw $s5, 256($a0)
    	sw $s6, 260($a0)
	sw $s6, 264($a0)
	sw $s6, 268($a0)
	sw $s5, 272($a0)
	
	sw $s5, 512($a0)
    	sw $s6, 516($a0)
	sw $s5, 520($a0)
	sw $s6, 524($a0)
	sw $s5, 528($a0)
	
	sw $s5, 768($a0)
    	sw $s6, 772($a0)
	sw $s6, 776($a0)
	sw $s6, 780($a0)
	sw $s5, 784($a0)
	
	sw $s5, 1024($a0)
    	sw $s6, 1028($a0)
	sw $s5, 1032($a0)
	sw $s6, 1036($a0)
	sw $s5, 1040($a0)
	
	sw $s5, 1280($a0)
    	sw $s6, 1284($a0)
	sw $s6, 1288($a0)
	sw $s6, 1292($a0)
	sw $s5, 1296($a0)
	
	sw $s5, 1536($a0)
    	sw $s5, 1540($a0)
	sw $s5, 1544($a0)
	sw $s5, 1548($a0)
	sw $s5, 1552($a0)
	
	jr $ra
	
    dn_nine: 
    	sw $s5, 0($a0)
    	sw $s5, 4($a0)
	sw $s5, 8($a0)
	sw $s5, 12($a0)
	sw $s5, 16($a0)
	
	sw $s5, 256($a0)
    	sw $s6, 260($a0)
	sw $s6, 264($a0)
	sw $s6, 268($a0)
	sw $s5, 272($a0)
	
	sw $s5, 512($a0)
    	sw $s6, 516($a0)
	sw $s5, 520($a0)
	sw $s6, 524($a0)
	sw $s5, 528($a0)
	
	sw $s5, 768($a0)
    	sw $s6, 772($a0)
	sw $s6, 776($a0)
	sw $s6, 780($a0)
	sw $s5, 784($a0)
	
	sw $s5, 1024($a0)
    	sw $s5, 1028($a0)
	sw $s5, 1032($a0)
	sw $s6, 1036($a0)
	sw $s5, 1040($a0)
	
	sw $s5, 1280($a0)
    	sw $s5, 1284($a0)
	sw $s5, 1288($a0)
	sw $s6, 1292($a0)
	sw $s5, 1296($a0)
	
	sw $s5, 1536($a0)
    	sw $s5, 1540($a0)
	sw $s5, 1544($a0)
	sw $s5, 1548($a0)
	sw $s5, 1552($a0)
	
	jr $ra
	
# ---------------------------------------------------- #

# ------- Check if Player has Won ------- #
# Check if the players score meets the threshhold required to win.
# This number is stored as WIN_POINTS
check_game_win:
	la $s0, scoreboard 
	lh $s0, 0($s0) #We just need the points
	
	bge $s0, WIN_POINTS, won_game
	jr $ra #return if the point requirement is met
	
    won_game:
    	j game_won_loop
    	
# ---------------------------------------- #

# ------ Game Won Loop -------- #
# Draw the game won banner, then wait until the player restarts the game with 'p'
game_won_loop:
    gwl_draw_banner:
    	#calculate the offset
    	li $s0, BASE_ADDRESS
    	li $s1, WIN_X
    	li $s2, WIN_Y
    	sll $s1, $s1, 2
    	sll $s2, $s2, 8
    	add $s0, $s0, $s1
    	add $s0, $s0, $s2
    	
    	#Load the colors into s1 and s2
    	li $s2, MAIN_GREEN
    	li $s1, WHITE
    	
    	#start drawing
	sw $s2, 0($s0) #row 1
	sw $s2, 4($s0)
	sw $s2, 8($s0)
	sw $s2, 12($s0)
	sw $s2, 16($s0)
	sw $s2, 20($s0)
	sw $s2, 24($s0)
	sw $s2, 28($s0)
	sw $s2, 32($s0)
	sw $s2, 36($s0)
	sw $s2, 40($s0)
	sw $s2, 44($s0)
	sw $s2, 48($s0)
	sw $s2, 52($s0)
	sw $s2, 56($s0)
	sw $s2, 60($s0)
	sw $s2, 64($s0)
	sw $s2, 68($s0)
	sw $s2, 72($s0)
	sw $s2, 76($s0)
	sw $s2, 80($s0)
	sw $s2, 84($s0)
	sw $s2, 88($s0)
	sw $s2, 92($s0)
	sw $s2, 96($s0)
	sw $s2, 100($s0)
	sw $s2, 104($s0)
	sw $s2, 108($s0)
	sw $s2, 112($s0)
	sw $s2, 116($s0)
	sw $s2, 120($s0)
	sw $s2, 124($s0)
	
	sw $s2, 256($s0) #row 2
	sw $s1, 260($s0)
	sw $s2, 264($s0)
	sw $s2, 268($s0)
	sw $s2, 272($s0)
	sw $s1, 276($s0)
	sw $s2, 280($s0)
	sw $s2, 284($s0)
	sw $s2, 288($s0)
	sw $s2, 292($s0)
	sw $s2, 296($s0)
	sw $s2, 300($s0)
	sw $s2, 304($s0)
	sw $s2, 308($s0)
	sw $s2, 312($s0)
	sw $s2, 316($s0)
	sw $s2, 320($s0)
	sw $s1, 324($s0)
	sw $s2, 328($s0)
	sw $s2, 332($s0)
	sw $s2, 336($s0)
	sw $s1, 340($s0)
	sw $s2, 344($s0)
	sw $s2, 348($s0)
	sw $s2, 352($s0)
	sw $s2, 356($s0)
	sw $s2, 360($s0)
	sw $s2, 364($s0)
	sw $s2, 368($s0)
	sw $s2, 372($s0)
	sw $s1, 376($s0)
	sw $s2, 380($s0)
	
	sw $s2, 512($s0) #row 3
	sw $s1, 516($s0)
	sw $s2, 520($s0)
	sw $s2, 524($s0)
	sw $s2, 528($s0)
	sw $s1, 532($s0)
	sw $s2, 536($s0)
	sw $s2, 540($s0)
	sw $s2, 544($s0)
	sw $s2, 548($s0)
	sw $s2, 552($s0)
	sw $s2, 556($s0)
	sw $s2, 560($s0)
	sw $s2, 564($s0)
	sw $s2, 568($s0)
	sw $s2, 572($s0)
	sw $s2, 576($s0)
	sw $s1, 580($s0)
	sw $s2, 584($s0)
	sw $s2, 588($s0)
	sw $s2, 592($s0)
	sw $s1, 596($s0)
	sw $s2, 600($s0)
	sw $s2, 604($s0)
	sw $s2, 608 ($s0)
	sw $s2, 612 ($s0)
	sw $s2, 616 ($s0)
	sw $s2, 620 ($s0)
	sw $s2, 624 ($s0)
	sw $s2, 628 ($s0)
	sw $s1, 632 ($s0)
	sw $s2, 636 ($s0)
	
	sw $s2, 768($s0) #row 4
	sw $s2, 772($s0)
	sw $s1, 776($s0)
	sw $s2, 780($s0)
	sw $s1, 784($s0)
	sw $s2, 788($s0)
	sw $s2, 792($s0)
	sw $s1, 796($s0)
	sw $s1, 800($s0)
	sw $s2, 804($s0)
	sw $s2, 808($s0)
	sw $s1, 812($s0)
	sw $s2, 816($s0)
	sw $s2, 820($s0)
	sw $s1, 824($s0)
	sw $s2, 828($s0)
	sw $s2, 832($s0)
	sw $s1, 836($s0)
	sw $s2, 840($s0)
	sw $s2, 844($s0)
	sw $s2, 848($s0)
	sw $s1, 852($s0)
	sw $s2, 856($s0)
	sw $s1, 860($s0)
	sw $s2, 864 ($s0)
	sw $s1, 868 ($s0)
	sw $s1, 872 ($s0)
	sw $s1, 876 ($s0)
	sw $s2, 880 ($s0)
	sw $s2, 884 ($s0)
	sw $s1, 888 ($s0)
	sw $s2, 892 ($s0)
	
	sw $s2, 1024($s0) #row 5
	sw $s2, 1028($s0)
	sw $s2, 1032($s0)	
	sw $s1, 1036($s0)
	sw $s2, 1040($s0)
	sw $s2, 1044($s0)
	sw $s1, 1048($s0)
	sw $s2, 1052($s0)
	sw $s2, 1056($s0)
	sw $s1, 1060($s0)
	sw $s2, 1064($s0)
	sw $s1, 1068($s0)
	sw $s2, 1072($s0)
	sw $s2, 1076($s0)
	sw $s1, 1080($s0)
	sw $s2, 1084($s0)
	sw $s2, 1088($s0)
	sw $s1, 1092($s0)
	sw $s2, 1096($s0)
	sw $s1, 1100($s0)
	sw $s2, 1104($s0)
	sw $s1, 1108($s0)
	sw $s2, 1112($s0)
	sw $s2, 1116($s0)
	sw $s2, 1120 ($s0)
	sw $s1, 1124 ($s0)
	sw $s2, 1128 ($s0)
	sw $s2, 1132 ($s0)
	sw $s1, 1136 ($s0)
	sw $s2, 1140 ($s0)
	sw $s1, 1144 ($s0)
	sw $s2, 1148 ($s0)
	
	sw $s2, 1280($s0) #row 6
	sw $s2, 1284($s0)
	sw $s2, 1288($s0)
	sw $s1, 1292($s0)
	sw $s2, 1296($s0)
	sw $s2, 1300($s0)
	sw $s1, 1304($s0)
	sw $s2, 1308($s0)
	sw $s2, 1312($s0)
	sw $s1, 1316($s0)
	sw $s2, 1320($s0)
	sw $s1, 1324($s0)
	sw $s2, 1328($s0)
	sw $s2, 1332($s0)
	sw $s1, 1336($s0)
	sw $s2, 1340($s0)
	sw $s2, 1344($s0)
	sw $s1, 1348($s0)
	sw $s1, 1352($s0)
	sw $s2, 1356($s0)
	sw $s1, 1360($s0)
	sw $s1, 1364($s0)
	sw $s2, 1368($s0)
	sw $s1, 1372($s0)
	sw $s2, 1376 ($s0)
	sw $s1, 1380 ($s0)
	sw $s2, 1384 ($s0)
	sw $s2, 1388 ($s0)
	sw $s1, 1392 ($s0)
	sw $s2, 1396 ($s0)
	sw $s2, 1400 ($s0)
	sw $s2, 1404 ($s0)
	
	sw $s2, 1536($s0) #row 7
	sw $s2, 1540($s0)
	sw $s2, 1544($s0)
	sw $s1, 1548($s0)
	sw $s2, 1552($s0)
	sw $s2, 1556($s0)
	sw $s2, 1560($s0)
	sw $s1, 1564($s0)
	sw $s1, 1568($s0)
	sw $s2, 1572($s0)
	sw $s2, 1576($s0)
	sw $s2, 1580($s0)
	sw $s1, 1584($s0)
	sw $s1, 1588($s0)
	sw $s1, 1592($s0)
	sw $s2, 1596($s0)
	sw $s2, 1600($s0)
	sw $s1, 1604($s0)
	sw $s2, 1608($s0)
	sw $s2, 1612($s0)
	sw $s2, 1616($s0)
	sw $s1, 1620($s0)
	sw $s2, 1624($s0)
	sw $s1, 1628($s0)
	sw $s2, 1632 ($s0)
	sw $s1, 1636 ($s0)
	sw $s2, 1640 ($s0)
	sw $s2, 1644 ($s0)
	sw $s1, 1648 ($s0)
	sw $s2, 1652 ($s0)
	sw $s1, 1656 ($s0)
	sw $s2, 1660 ($s0)
	
	sw $s2, 1792($s0) #row 8
	sw $s2, 1796($s0)
	sw $s2, 1800($s0)
	sw $s2, 1804($s0)
	sw $s2, 1808($s0)
	sw $s2, 1812($s0)
	sw $s2, 1816($s0)
	sw $s2, 1820($s0)
	sw $s2, 1824($s0)
	sw $s2, 1828($s0)
	sw $s2, 1832($s0)
	sw $s2, 1836($s0)
	sw $s2, 1840($s0)
	sw $s2, 1844($s0)
	sw $s2, 1848($s0)
	sw $s2, 1852($s0)
	sw $s2, 1856($s0)
	sw $s2, 1860($s0)
	sw $s2, 1864($s0)
	sw $s2, 1868($s0)
	sw $s2, 1872($s0)
	sw $s2, 1876($s0)
	sw $s2, 1880($s0)
	sw $s2, 1884($s0)
	sw $s2, 1888 ($s0)
	sw $s2, 1892 ($s0)
	sw $s2, 1896 ($s0)
	sw $s2, 1900 ($s0)
	sw $s2, 1904 ($s0)
	sw $s2, 1908 ($s0)
	sw $s2, 1912 ($s0)
	sw $s2, 1916 ($s0)
    
    gwl_wait_for_reset:
    	li $t9, KEYPRESS_ADDRESS
	lw $t8, 0($t9)
	bne $t8, 1, gwl_wait_for_reset
	
	#If a key was pressed, make sure it was p, otherwise ignore
	lw $t8, 4($t9)
	bne $t8, 0x70, gwl_wait_for_reset

	#Restart the game and re-initialize everything.
	j start_game
