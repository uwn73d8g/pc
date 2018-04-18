	# main()
	#  r1 is return address
	#  r7 is stack pointer

	# As of V1.1.0, the call hardware instruction
	#  assumes the function is located at an even
	#  address.
	# The .align directive makes moves the load point
	#  rounds the load point up to the next even address.

	.align
main:   sw      r1  r0  r7      # push return address
	addi    r7  r7 $-2      # update stack pointer

	addi    r7  r7 $-4      # allocate space for return val and 1 arg
	addi    r2  r0 $4       # index from sp to 1st arg
	addi    r3  r0 $4       # first arg value
	sw      r3  r7 r2       # store in stack frame
#	addi    r2  r2 $-2      # index from sp to 2nd arg
#	addi    r3  r0 $10      # second arg value
#	sw      r3  r7 r2       # store in stack frame
	# call    r1  max         # call max
	# note: at this point we have no idea what's in any register
	#       (except r0 and r7)
	# addi    r2  r0 $6       # index from sp to return value
	# lw      r3  r7 r2       # fetch return value into r3
	# addi    r7  r7 $6       # restore stack pointer

	# printr  r3              # print the max

	call    r1  fact
	addi    r2  r0 $4       # index from sp to return value
	lw      r3  r7 r2       # fetch return value into r3
	addi    r7  r7 $6       # restore stack pointer

	printr  r5              # print the fact

	addi    r1  r7 $2       # restore stack pointer
	lw      r1  r0 r1       # fetch return address
	jr      r0  r0 r1       # return
