# Written by: Charlie Alpert
# Purpose: Program takes a file and encrypts or decrypts it based on user input.


 		.include "SysCalls.asm"		
		.data
menuPrint: 	.asciiz	"\n1: Encrypt the file. \n2: Decrypt the file. \n3: Exit. \n"
inputFilePrint:	.asciiz	"\nFile name: "
fileErrorPrint:	.asciiz	"\nFile error."
inputKeyPrint:	.asciiz "\nKey: "
keyErrorPrint:	.asciiz "\nKey error. "
txt:		.asciiz "txt"
enc:		.asciiz "enc"

		.eqv 	fileSize 255
filename:	.space 	fileSize
		
		.eqv	keySize	60
key:		.space	keySize

		.eqv	blockSize 1024
block: 		.space	blockSize

		.text
		
# s0: filename
# s1: block
# s2: key
# s3: menu choice
# s4: file descriptor for source file
# s5: file descriptor for destination file
# s6: address of destination file / bytes read
# s7: total bytes read

###################################################################################################	
		
# MENU AND FILE/KEY INPUT SECTION		
		
menu:		# print menu
		la 	$a0, menuPrint		# gets address of user prompt menu
		li 	$v0, SysPrintString	# call to print user prompt menu
		syscall	
		
		# get menu option
		li 	$v0, SysReadInt		# reads in integer 
		syscall 
		
				
		blt 	$v0, 3, fileInput	# if number is not 3 goes to rest of program
		
		# exit program
		li 	$v0, SysExit		# call to exit
		syscall 
		
		
fileInput:	# put menu option in a3
		move 	$a3, $v0								

		# print file input message
		la 	$a0, inputFilePrint	# input message
		li 	$v0, SysPrintString	# call to print
		syscall		
		
		# read in filename
		la 	$a0, filename		
		li 	$a1, fileSize		# length of string
		li 	$v0, SysReadString	# reads in file 
		syscall 
		
		# load file into a0
		la	$a0, filename		# a0 pointer to filename
		
		jal	removeNewline		# remove newline from filename 
		# (no stack allocation bc no nested calls)
						
		# print key input
		la 	$a0, inputKeyPrint	# input message
		li 	$v0, SysPrintString	# call to print
		syscall	
		
		# read in key
		la 	$a0, key		
		li 	$a1, keySize		# length of string
		li 	$v0, SysReadString	# reads in key 
		syscall 
		

		# load into variables		
		la 	$a0, filename		
		la 	$a1, block
		la 	$a2, key
		# a3 = menu choice									
		
		
		jal cryption			# run cryption method 
		# (no stack allocation bc no nested calls)
		j menu				# loop back to main menu
		

###################################################################################################		
				

# ENCRYPTION / DECRYPTION SECTION
									
cryption:	# allocate stack space and store variables
		addi	$sp, $sp, -36 
		sw 	$ra, 0($sp)
		sw 	$s0, 4($sp)
		sw 	$s1, 8($sp)
		sw 	$s2, 12($sp)
		sw 	$s3, 16($sp)
		sw 	$s4, 20($sp)
		sw 	$s5, 24($sp)
		sw	$s6, 28($sp)
		sw	$s7, 32($sp)	
		
		# store into stack registers
		move 	$s0, $a0 		# store filename in s0
		move 	$s1, $a1 		# store block in s1
		move 	$s2, $a2 		# store key in s2
		move 	$s3, $a3 		# store menu choice in s3
		
		# check if is key valid		
		lbu 	$t0, 0($a2)		# see if first of key is newline
		beq 	$t0,'\n', keyError	# when first character is newline, key is empty	
	
		# open file		
		la	$a0, filename		# load filename
		li	$a1, 0			# read flag
		li 	$a2, 0			# mode
		li	$v0, SysOpenFile		
		syscall
		
		
		# check that file exists
		bltz  	$v0, fileError		# v0 < 0 when file does not exist
		move 	$s4, $v0		# save file descriptor

		# get length of filename
		move 	$a0, $s0			
		jal 	length
		
		
		# allocate space of filname
		move 	$a0, $v0
		li 	$v0, SysAlloc
		syscall
		move 	$s5, $v0		# store address of destination string (allocated)
			
																					
		# copy over source file string to destination file string																													
		move 	$a0, $s5		# move destination string to a0 for copy method
		move 	$a1, $s0		# address of source file string to a1	
		jal 	copyString
											  	  
		move 	$s6, $s5 		# s6 set to pointer to address of destination file																					
																																																																			

findExtension:	# gets extension of input file
		move 	$a0, $s6		# a0 holds address of destination file
		li 	$a1, '.'		# a1 to hold character '.'
		jal 	charSearch		# v0 will equal index of '.' (0 if not in filename) 
		beq 	$v0, $zero, setExten	# once not found will end loop
		addiu	$s6, $v0, 1		# increase s6 pointer 
		j 	findExtension
		
		
	
setExten:	# determines which extension for output file
		beq 	$s3, 1, encExtension	# menu option 1 so encryption 
		# otherwise decryption	
		# set extension to .txt		
		la 	$a1, txt		
		j 	openOutput
	
	
encExtension:	# set extension to .enc
		la 	$a1, enc
	
openOutput:	# prepare output file and open

		# s6 now holds pointer to '.' extension in order to replace it
		move 	$a0, $s6
		jal 	copyString		# makes filename with proper extension
		
		move 	$a0, $s5 		# setting $a0 to output file name
		li 	$a1, 1			# flag = write only
		li 	$a2, 0
		li 	$v0, SysOpenFile	# opening output file
		syscall
		
		bltz  	$v0, fileError		# file does not exist
		move 	$s5, $v0 		# s5 store file descriptor of output 
	
		li 	$s7, 0		
			
		
readFile:	# read 1024 byte block of file
		move 	$a0, $s4		# load a0 with file descriptor (input file)
		move 	$a1, $s1		# load a1 with address of buffer
		li 	$a2, blockSize		# read 1024 characters
		li 	$v0, SysReadFile		
		syscall
		
		beqz  	$v0, closeFiles		# 0 characters = done with en/de cryption
		bltz 	$v0, fileError2		# negative file descriptor = file error
		add 	$s7, $s7, $v0 		# add $s7 with number of bytes read
		move 	$s6, $v0 		# save number of bytes read
						
		# set temporary registers with key and block				
		move 	$t1, $s1		# block pointer
		move 	$t2, $s2 		# key pointer
		
		
		
bufferByte:	# loads each character in buffer / block to t0
		lbu 	$t0, 0($t1)		# loads char / byte in block
	
			
keyByte:	# loads each character in key
		lbu 	$t3, 0($t2)		# loads char / byte in key
		bne 	$t3, '\n', encOrDec	# once at end (newline) exit loop
		move 	$t2, $s2
		#addi	$t2, $t2, 1		# increment key pointer
		j 	keyByte
		
		
		
encOrDec:	# adds or subtrancts depending on en / de cryption
		beq	$s3, 1, encryption	# menu = 1 = encryption
		# otherwise decryption
		
		# decryption algortihm
		subu	$t0, $t0, $t3		# subtract byte of key
		j 	updateFile
		
		
encryption:	# encryption algorithm
		addu	$t0, $t0, $t3		# add byte of key
		
		
updateFile:	# write to file
		sb 	$t0, 0($t1) 		# store new char back in block
		addi 	$t1, $t1, 1 		# increment block / buffer pointer
		addi 	$t2, $t2, 1		# incremnt key pointer
		addi 	$v0, $v0, -1		# subtract 1 from block byte count
		bnez  	$v0, bufferByte		# read in new byte as long as count is not zero
		
		
		# done crypting -> write to file
		move 	$a0, $s5		# load in destination file descriptor
		move 	$a1, $s1		# address of buffer block
		move 	$a2, $s6		# total size of block buffer 
		li 	$v0, SysWriteFile
		syscall 
		
		bltz 	$v0, fileError2		# negative number = error
		j 	readFile		# back to read next block of file



###################################################################################################

# DONE WITH ENCRYPTION - CLOSE FILES AND REALLOCATE STACK SPACE																																		
																																																																																																						
closeFiles:	# close source and destination files
		move	$a0, $s4		# load input file descriptor
		li	$v0, SysCloseFile	
		syscall
		
		move	$a0, $s5		# load output file descriptor
		li	$v0, SysCloseFile	
		syscall
		
		move 	$v0, $s7

																																																							
cryptionDone:	# encrypting / decrypting done, reload stack
		lw 	$ra, 0($sp)				
		lw 	$s0, 4($sp)
		lw 	$s1, 8($sp)
		lw 	$s2, 12($sp)
		lw 	$s3, 16($sp)
		lw	$s4, 20($sp)
		lw 	$s5, 24($sp)
		lw 	$s6, 28($sp)
		lw 	$s7, 32($sp)
		addi 	$sp, $sp, 36			
		jr 	$ra		
		

###################################################################################################

# SOURCE TO DESTINATION COPY FILENAME OR STRING	
						 
copyString:	# $a1 = address of source string 
		# $a0 = address of destination string 
		lb 	$t0, 0($a1)
		beq 	$t0, $zero, copyStringDone
		sb 	$t0, 0($a0)
		addi 	$a0, $a0, 1
		addi 	$a1, $a1, 1
		j 	copyString
		
copyStringDone:	# store null terminator and exit method
		sb 	$t0, 0($a0)
		jr 	$ra 



	
###################################################################################################	
		
# LENGTH CALCULATION			
														
length:		# find length of string and return in v0
		li 	$v0, 0 
length2:
		# a0 = address of filename
		lbu 	$t0, 0($a0)
		beq 	$t0, $zero, lengthDone
		addi 	$a0, $a0, 1
		addi 	$v0, $v0, 1
		j 	length2
		
lengthDone:	# found length / return to cryption
		jr 	$ra
	
	
																			
		
###################################################################################################	
			
# REMOVE / REPLACE NEW LINE SECTION
		
removeNewline:	# remove newline from string in a0
		# a0 points to filename / key
		lbu 	$t0, 0($a0)			# grabs character in filename stores in t0
		beq 	$t0, $zero, newlineDone	# null terminator in place go to exit	
		beq 	$t0,'\n',replaceToNull		# if t1 is newline go to replace with null
		addi 	$a0, $a0, 1			# increment a0 pointer
		j 	removeNewline
		
replaceToNull:	# replaces newline with null terminator
		sb 	$zero, 0($a0)			

newlineDone:	# remove newline exit / return to main
		jr 	$ra	 		

		
	
				
###################################################################################################

# FINDS CHARACTER IN STRING

charSearch:
		# finds first occurence of character in a1				
		# sets v0 to pointer of character
		lbu 	$t0, 0($a0) 				# load character of string into t0
		beq 	$t0, $zero, charNotFound		# if t0 is null then character isn't found
		beq 	$t0, $a1, charFound			# character found in t0
		addi 	$a0, $a0, 1				# increment pointer
		j 	charSearch
						
charFound:	# returns pointer of character
		move 	$v0, $a0 
		jr 	$ra
		
charNotFound:	# returns 0 since character isn't found
		#lw  	$v0, ($zero) 				
		addiu 	$v0, $zero, 0   #***
		jr 	$ra

							
													
							
###################################################################################################																		
			
# ERROR MESSAGES					
		
keyError:	# key error
		la 	$a0, keyErrorPrint	# error message for user	
		li 	$v0, SysPrintString	# call to print
		syscall			
		j 	cryptionDone
		
		
fileError:	#file error / file does not exist
		la 	$a0, fileErrorPrint	# error message for user	
		li 	$v0, SysPrintString	# call to print
		syscall	
		j 	cryptionDone	
		
		
fileError2:	#file error / file does not exist
		la 	$a0, fileErrorPrint	# error message for user	
		li 	$v0, SysPrintString	# call to print
		syscall	
		j 	closeFiles	
				
				
		
###################################################################################################
																	
