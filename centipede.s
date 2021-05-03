#####################################################################
#
# CSC258H Winter 2021 Assembly Final Project
# University of Toronto, St. George
#
# Student: Johanna Zhang
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
#####################################################################
.data
	displayAddress:	.word 0x10008000
	bugLocation: .word 1008
	centipedeLocation: .word 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
	centipedeDirection: .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	
	numMushrooms: .word 20
	mushroomAddress: .word 0x10010080
	
	backgroundColour: .word 0x000000
	centipedeColour: .word 0xbced5f
	centipedeHeadColour: .word 0x72ab07
	mushroomColour: .word 0xc2aa88
	bugBlasterColour: .word 0xeda4dd
	dartColour: .word 0xf75297
	fleaColour: .word 0xf2ba1f
	wowColour: .word 0x97e5f0 
.text 
#####################################################################
# locations
# bug blaster location stored in $s0 (x), y=31
# centipede location and direction stored in arrays $a1 $sa2 (location,direciton)
# flea location stored in $s3 $s4 (x,y)
# dart location stored in $s5 $s6 (x,y)
# num times centipede was hit stored in $s7

#####################################################################
# initialize game data
.globl main

.text
main: 
	li $t0, 0			# counter for num mushrooms
	lw $t1, numMushrooms		# maximum number of mushrooms
	lw $t2, mushroomAddress		# location of *current* mushroom data
	
#####################################################################
# initialize mushrooms 
mushroom_init_loop:
	jal get_random_number			# Get random number (0-27) in $a0
	addi $a0, $a0, 2			
	sh $a0, 0($t2)				# Store into current mushroom x
	
	jal get_random_number			# Get random number (0-27) in $a0
	addi $a0, $a0, 1
	sh $a0, 2($t2)				# Store into current mushroom Y
	 	
	addi $t0, $t0, 1			# Increment mushroom counter				
	addi $t2, $t2, 4			# Go to address of next mushroom data
	blt $t0, $t1, mushroom_init_loop	# If not done all mushrooms, loop
	
#####################################################################
# initialize flea location
	jal get_random_number		# Get random number (0-27) in $a0
	addi $s3, $a0, 1		# store into flea.x
	li $s4, 0			# flea.y = 0
	
#####################################################################
# intiialize centipede location
	li $t0, 0 			# t0 = counter
	addi $a3, $zero, 11	 	# load a3 with the loop count (11)
	la $a1, centipedeLocation 	# load the address of the array into $a1
	la $a2, centipedeDirection 	# load the address of the array into $a2

reset_centipede:			# iterate over the loops elements to reset centipede segments
	sw $t0, 0($a1)		 	# store counter number in centipedeLocation array
	li $t5, 1			
	sw $t5, 0($a2)		 	# store direction 1 in centipedeDirection  array 

	addi $a1, $a1, 4	 	# increment $a1 by one, to point to the next element in the array
	addi $a2, $a2, 4
	addi $t0, $t0, 1	 	# increment counter
	bne $a3, $t0, reset_centipede

#####################################################################
# intiialize dart location
	li $s5, -1			# dart doesn't exist yet
	li $s6, -1
#####################################################################
# intiialize number of times centipede is hit by dart
	li $s7, 0
	
#####################################################################
# draw background
draw_bg:
	lw $t0, displayAddress		# Location of current pixel data
	addi $t1, $t0, 4096		# Location of last pixel data. Hard-coded below.
						# 32x32 = 1024 pixels x 4 bytes = 4096.
	lw $t2, backgroundColour	# Colour of the background
	
draw_bg_loop:
	sw $t2, 0($t0)			# Store the colour
	addi $t0, $t0, 4		# Next pixel
	blt $t0, $t1, draw_bg_loop
	
	jal draw_mushrooms		# draw mushrooms
	
#####################################################################
# GAME LOOP					
Loop:

	jal disp_centipede
	jal draw_flea
	jal move_flea
	jal check_keystroke
	jal move_dart
	
	li $v0, 32				# Sleep op code
	li $a0, 100				# Sleep 1/20 second 
	syscall
	
	j Loop	

Exit:
	li $v0, 10		# terminate the program gracefully
	syscall

#####################################################################
# FUNCTIONS
#####################################################################
# display and move centipede	
disp_centipede:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	addi $a3, $zero, 11	 	# load a3 with the loop count (11)
	la $a1, centipedeLocation 	# load the address of the array into $a1
	la $a2, centipedeDirection 	# load the address of the array into $a2

arr_loop:				# iterate over the loops elements to draw each body in the centiped
	lw $t1, 0($a1)			# load a word from the centipedeLocation array into $t1
	lw $t5, 0($a2)			# load a word from the centipedeDirection  array into $t5
	
	bne $a3, 11, continue		# if not the tail of centipede continue
	beq $t1, 992, end_game		# otherwise, if tail of centipede is at bottom left, end game	
	
	continue:
	li $t2, 0x10008000 		# $t2 stores the base address for display
	lw $t3, centipedeColour		# $t3 stores the centipede colour code
	
	sll $t4, $t1, 2			# $t4 is the bias of the old body location in memory (offset*4)
	add $t4, $t2, $t4		# $t4 is the address of the old bug location
	beq $a3, 11, paint_centipede	# if tail of the centipede, paint black
	sw $t3, 0($t4)			# paint the body green
	j move_cent
	
	paint_centipede:
	li $t7, 0x000000
	sw $t7, 0($t4)			# paint centipede end black
	
	#################################################
	# move centipede / check if centipede hit edge
	move_cent:
	li $t8, 32
	div $t1, $t8			# divide location by 32
	mfhi $t3			# store remainder
	beqz $t3, check_direction_neg	# check direction if remainder is 0
	addi $t9, $t1, -31
	div $t9, $t8			# divide location by 32
	mfhi $t3			# store remainder
	beqz $t3, check_direction_pos	# check direction if remainder is 0 
	j cent_hit_mushroom		# check if hit mushroom if not at edge
	
	check_direction_neg:
		beq $t5, 1, move_right	# if at left edge and moving right, move right
		j move_down		# otherwise, descend level
		
	check_direction_pos:
		beq $t5, -1, move_left	# if at right edge and moving left, move left
		j move_down		# otherwise, descend level
	
	#################################################
	# check if centipede hit mushroom
	cent_hit_mushroom:
	li $t0, 0			# START centipede HIT mushroom
	lw $t6, numMushrooms
	lw $t2, mushroomAddress
	
	cent_hit_mushroom_start:
	beq $t5, -1, cent_hit_mushroom_left			# if going left, check if hit mushroom at left
					
	cent_hit_mushroom_right: 				# check if hit mushroom at right
		addi $t9, $t1, 1				# t9 = centipede location + 1
		lh $t7, 2($t2)					# Load in Y of current mushroom
		beq $t7, -1, cent_hit_mushroom_loop_inc		# if t7 == -1, mushroom no longer exists, check next mushroom
		lh $t8, 0($t2)					# t8 = mushroom.x
		beq $t8, -1, cent_hit_mushroom_loop_inc
		sll $t7, $t7, 5					# t7 = mushroom.y * 32
		add $t7, $t7, $t8				# t7 = (mushroom.y * 32) + x
		bne $t7, $t9, cent_hit_mushroom_loop_inc	# If mushroom location != centipede location + 1: continue

		# mushroom has been hit here...
		j move_down
		
	cent_hit_mushroom_left: 				# check if hit mushroom at left
		addi $t9, $t1, -1				# t9 = centipede location - 1
		lh $t7, 2($t2)					# Load in Y of current mushroom
		beq $t7, -1, cent_hit_mushroom_loop_inc		# if t7 == -1, mushroom no longer exists, check next mushroom 
		lh $t8, 0($t2)					# t8 = mushroom.x
		beq $t8, -1, cent_hit_mushroom_loop_inc
		sll $t7, $t7, 5					# t7 = mushroom.y * 32
		add $t7, $t7, $t8				# t7 = (mushroom.y * 32) + x
		bne $t7, $t9, cent_hit_mushroom_loop_inc	# If mushroom location != centipede location - 1: continue

		# mushroom has been hit here...
		j move_down

	cent_hit_mushroom_loop_inc:				# go to next mushroom
		addi $t0, $t0, 1
		addi $t2, $t2, 4
		blt $t0, $t6, cent_hit_mushroom_start
	
	centipede_hit_loop_end:			# continue moving as normal if no collisions 		
		beq $t5, 1, move_right		
		beq $t5, -1, move_left
		
	#################################################
	# centipede movements							
	move_right:
	addi $t1, $t1, 1		# centipede location ++
	sw $t1, 0($a1)			# store new centipede location
	j increment			# check next segment
	
	move_left:		
	addi $t1, $t1, -1		# centipede location --
	sw $t1, 0($a1)			# store new centipede location	
	j increment			# check next segment
	
	move_down:
	addi $t1, $t1, 32		# descend level
	sw $t1, 0($a1)			# store new location
	mul $t5, $t5, -1		# change direction
	sw $t5, 0($a2)			# store new direction
	j increment			# check next segment
	
	increment:
	addi $a1, $a1, 4	 	# increment $a1 by one, to point to the next element in the array
	addi $a2, $a2, 4
	addi $a3, $a3, -1	 	# decrement $a3 by 1
	bne $a3, $zero, arr_loop
	
	li $t3, 0x72ab07		# $t3 stores the centipede head colour code
	sw $t3, 0($t4)			# paint the head with dark green
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#####################################################################
# function to detect any keystroke
check_keystroke:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t8, 0xffff0000
	beq $t8, 1, get_keyboard_input # if key is pressed, jump to get this key
	addi $t8, $zero, 0
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
# function to get the input key
get_keyboard_input:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t2, 0xffff0004
	addi $v0, $zero, 0	#default case
	beq $t2, 0x6A, respond_to_j
	beq $t2, 0x6B, respond_to_k
	beq $t2, 0x78, respond_to_x
	beq $t2, 0x73, respond_to_s
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
	#################################################
	# Call back function of j key
	respond_to_j:
		# move stack pointer a work and push ra onto it
		addi $sp, $sp, -4
		sw $ra, 0($sp)
	
		la $t0, bugLocation	# load the address of buglocation from memory
		lw $t1, 0($t0)		# load the bug location itself in t1
		addi $s0, $t1, -992
	
		lw $t2, displayAddress  # $t2 stores the base address for display
		li $t3, 0x000000	# $t3 stores the black colour code
	
		sll $t4,$t1, 2		# $t4 the bias of the old buglocation
		add $t4, $t2, $t4	# $t4 is the address of the old bug location
		sw $t3, 0($t4)		# paint the first (top-left) unit white.
	
		beq $t1, 992, skip_j 	# prevent the bug from getting out of the canvas
		addi $t1, $t1, -1	# move the bug one location to the right
		addi $s0, $t1, -992
		
		skip_j:
			sw $t1, 0($t0)		# save the bug location

			li $t3, 0xeda4dd	# $t3 stores the purple colour code
	
			sll $t4,$t1, 2
			add $t4, $t2, $t4
			sw $t3, 0($t4)		# paint the first (top-left) unit purple.
	
		# pop a word off the stack and move the stack pointer
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
	
	#################################################
	# Call back function of k key
	respond_to_k:
		# move stack pointer a work and push ra onto it
		addi $sp, $sp, -4
		sw $ra, 0($sp)
	
		la $t0, bugLocation	# load the address of buglocation from memory
		lw $t1, 0($t0)		# load the bug location itself in t1
		addi $s0, $t1, -992
	
		lw $t2, displayAddress  # $t2 stores the base address for display
		li $t3, 0x000000	# $t3 stores the black colour code
	
		sll $t4,$t1, 2		# $t4 the bias of the old buglocation
		add $t4, $t2, $t4	# $t4 is the address of the old bug location
		sw $t3, 0($t4)		# paint the block with black
	
		beq $t1, 1023, skip_k 	#prevent the bug from getting out of the canvas
		addi $t1, $t1, 1	# move the bug one location to the right
		addi $s0, $t1, -992
		
		skip_k:
			sw $t1, 0($t0)		# save the bug location

			li $t3, 0xeda4dd	# $t3 stores the purple colour code
	
			sll $t4,$t1, 2
			add $t4, $t2, $t4
			sw $t3, 0($t4)		# paint the block with purple
	
		# pop a word off the stack and move the stack pointer
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
	
	#################################################
	respond_to_x:
		# move stack pointer a work and push ra onto it
		addi $sp, $sp, -4
		sw $ra, 0($sp)
	
		addi $v0, $zero, 3
	
		addi $s5, $s0, 0	# dart.x = bugBlaster.x
		li $s6, 30		# dart.y = bugBlaster.y - 1
		jal draw_dart		# draw dart
	
		# pop a word off the stack and move the stack pointer
		lw $ra, 0($sp)
		addi $sp, $sp, 4	
		jr $ra
	
	#################################################
	respond_to_s:
		# move stack pointer a work and push ra onto it
		addi $sp, $sp, -4
		sw $ra, 0($sp)
	
		addi $v0, $zero, 4
	
		j main			# restart game
	
		# pop a word off the stack and move the stack pointer
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra

delay:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	li $a2, 10000
	addi $a2, $a2, -1
	bgtz $a2, delay
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

#####################################################################
# draw mushrooms 
draw_mushrooms:					
	li $t0, 0				# START draw mushroom 
	lw $t1, numMushrooms
	lw $t2, mushroomAddress		
	
draw_mushroom_loop:
	lh $t4, 2($t2)				# t4 = mushroom.y
	sll $t4, $t4, 5				# t4 = mushroom.y * 32
	lh $t5, 0($t2)				# t5 = mushroom.x
	add $t4, $t4, $t5			# t4 = mushroom.y * 32 + x
	sll $t4, $t4, 2				# t4 = (mushroom.y * 32 + x) * 4
	add $t4, $t4, $gp			# t4 = $gp + (mushroom.y * 32 + x) * 4   
	
	lw $a0, mushroomColour
	sw $a0, 0($t4)				# Store colour from $a0 into current pixel
	
	draw_mushroom_inc:
	addi $t0, $t0, 1			# Increment mushroom number
	addi $t2, $t2, 4			# Increment address of mushroom data
  	blt $t0, $t1, draw_mushroom_loop	# Jump back if not done with all mushrooms

	jr $ra

#####################################################################
# draw dart
draw_dart:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $a0, dartColour			# load dart colour
	sll $t0, $s6, 5				# t0 = dart.y * 32
	add $t0, $t0, $s5			# t0 = (dart.y * 32) + x
	sll $t0, $t0, 2				# t0 = (dart.y * 32 + x) * 4
	add $t0, $t0, $gp			# t0 = $gp + (dart.y * 32 + x) * 4
	sw $a0, 0($t0)				# draw dart
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra 
	
#####################################################################
# move dart
move_dart:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	beq $s5, -1, move_dart_end	# if dart doesn't exist, do nothing
	beq $s6, -1, move_dart_end	# if dart doesn't exist, do nothing
	jal did_dart_hit		# check if dart hit something
	
	li $a0, 0x000000	# paint previous flea location black
	sll $t0, $s6, 5		# t0 = flea.y * 32
	add $t0, $t0, $s5	# t0 = (flea.y * 32) + x
	sll $t0, $t0, 2		# t0 = (flea.y * 32 + x) * 4
	add $t0, $t0, $gp	# t0 = $gp + (flea.y * 32 + x) * 4
	sw $a0, 0($t0)
	
	addi $s6, $s6, -1	# decrement dart.y		
	jal draw_dart		# and draw the dart
	
	move_dart_end:
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#####################################################################
# check if dart hit
did_dart_hit:	
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	li $t0, 0				# START dart hit
	lw $t1, numMushrooms
	lw $t2, mushroomAddress	
	li $v0, 0				# hit = false
	#################################################
	# check if dart hit centipede
	addi $a3, $zero, 11	 	# load a3 with the loop count (10)
	la $a1, centipedeLocation 	# load the address of the array into $a1
		 		
	dart_hit_centipede_loop:
		lw $t5, 0($a1)				# load a word from the centipedeLocation array into $t5
		sll $t7, $s6, 5				# t7 = dart.y * 32
		add $t7, $t7, $s5			# t7 = (dart.y * 32) + x
		bne $t5, $t7, dart_hit_cent_inc		# check next segment if not hit
		
		li $v0, 1				# hit centipede, return = true
		centipede_hit:	
		addi $s7, $s7, 1			# increment number of times centipede hit
		beq $s7, 3, end_game			# end game if hit 3 times
		
		# pop a word off the stack and move the stack pointer
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
		dart_hit_cent_inc:
		addi $a1, $a1, 4	 		# increment $a1 by one, to point to the next element in the array
		addi $a3, $a3, -1	 		# decrement $a3 by 1
		bne $a3, $zero, dart_hit_centipede_loop
		
	#################################################
	# check if dart hit existing mushrooms
	dart_hit_mushroom_loop: 
		lh $a0, 2($t2)					# Load in Y of current mushroom
		bne $a0, -1, dart_hit_mushroom_loop_inc		# mushroom no longer exists
		bne $a0, $s6, dart_hit_mushroom_loop_inc	# If dart.y != mushroom.y: continue
	
		lh $a0, 0($t2)					# a0 = mushroom.x
		bne $a0, -1, dart_hit_mushroom_loop_inc		# mushroom no longer exists
		bne $s5, $a0, dart_hit_mushroom_loop_inc	# if dart.x != mushroom.x: continue 

		# dart has hit mushroom here...
		li $t6, -1
		sh $t6, 0($t2)
		sh $t6, 2($t2)				# set x and y to -1
		
		li $v0, 1				# hit platform, return = true
		
		# pop a word off the stack and move the stack pointer
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra

	dart_hit_mushroom_loop_inc:
		addi $t0, $t0, 1				# go to next mushroom
		addi $t2, $t2, 4
		blt $t0, $t1, dart_hit_mushroom_loop

	dart_hit_loop_end:
		# pop a word off the stack and move the stack pointer
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra		
						
#####################################################################
# draw flea
draw_flea:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	li $a0, 0xf2ba1f			# load flea colour
	sll $t0, $s4, 5				# t0 = flea.y * 32
	add $t0, $t0, $s3			# t0 = (flea.y * 32) + x
	sll $t0, $t0, 2				# t0 = (flea.y * 32 + x) * 4
	add $t0, $t0, $gp			# t0 = $gp + (flea.y * 32 + x) * 4
	sw $a0, 0($t0)				# draw flea 
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#####################################################################
# move flea
move_flea:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	li $t0, 31			# t0 = bug.y
	bne $t0, $s4, flea_hit_false	# check if bug.y = flea.y
	bne $s0, $s3, flea_hit_false	# check if bug.x = flea.x	
	j end_game			# end game if flea hit bug
		
	flea_hit_false:			# otherwise, move flea down
		li $a0, 0x000000	# paint previous flea location black
		sll $t0, $s4, 5		# t0 = flea.y * 32
		add $t0, $t0, $s3	# t0 = (flea.y * 32) + x
		sll $t0, $t0, 2		# t0 = (flea.y * 32 + x) * 4
		add $t0, $t0, $gp	# t0 = $gp + (flea.y * 32 + x) * 4
		sw $a0, 0($t0)		
		addi $s4, $s4, 1		# increment flea.y
		beq $s4, 32, move_flea_end	# if off screen, end 
		jal draw_flea			# draw current flea
	
	move_flea_end:
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#####################################################################
# get random number
get_random_number:
  	li $v0, 42         # Service 42, random int bounded
  	li $a0, 0          # Select random generator 0
  	li $a1, 27            
  	syscall            # Generate random int (returns in $a0)
  	jr $ra
  		
#####################################################################
# end game / display WOW!
end_game:
	lw $t0, displayAddress
	li $t1, 0x97e5f0
	#draw w 
	sw $t1, 1436($t0)
	sw $t1, 1564($t0)
	sw $t1, 1692($t0)
	sw $t1, 1820($t0)
	sw $t1, 1948($t0)
	sw $t1, 1824($t0)
	sw $t1, 1700($t0)
	sw $t1, 1832($t0)
	sw $t1, 1452($t0)
	sw $t1, 1580($t0)
	sw $t1, 1708($t0)
	sw $t1, 1836($t0)
	sw $t1, 1964($t0)
	#draw o
	sw $t1, 1460($t0)
	sw $t1, 1588($t0)
	sw $t1, 1716($t0)
	sw $t1, 1844($t0)
	sw $t1, 1972($t0)
	sw $t1, 1464($t0)
	sw $t1, 1468($t0)
	sw $t1, 1976($t0)
	sw $t1, 1980($t0)
	sw $t1, 1472($t0)
	sw $t1, 1600($t0)
	sw $t1, 1728($t0)
	sw $t1, 1856($t0)
	sw $t1, 1984($t0)
	#draw w
	sw $t1, 1480($t0)
	sw $t1, 1608($t0)
	sw $t1, 1736($t0)
	sw $t1, 1864($t0)
	sw $t1, 1992($t0) 
	sw $t1, 1868($t0)
	sw $t1, 1744($t0)
	sw $t1, 1876($t0)
	sw $t1, 1496($t0)
	sw $t1, 1624($t0)
	sw $t1, 1752($t0)
	sw $t1, 1880($t0)
	sw $t1, 2008($t0)
	#draw !
	sw $t1, 1504($t0)
	sw $t1, 1632($t0)
	sw $t1, 1760($t0)
	sw $t1, 2016($t0)
	
li $v0, 32 # sleep
li $a0, 1000
