	# int max(int x, int y)

	.align
max:    addi    r7  r7 $-4      # allocate stack space
	addi    r2  r0 $4       # index from sp to return address field
	sw      r1  r7 r2       # save return address

	addi    r2  r0 $8       # index from sp to x
	lw      r3  r7 r2       # r3 = x
	addi    r4  r0 $2       # index from sp to max
	sw      r3  r7 r4       # max = x

	addi    r2  r0 $6       # index from sp to y
	lw      r5  r7 r2       # r5 = y

	cmp     r0  r3 r5       # x cmp y
	bgt     :done           # skip ahead if x > y
	be      :done           # skip ahead if x == y
	sw      r5  r7 r4       # max = y
done:	lw      r5  r7 r4       # r5 = max
	addi    r3  r0 $10      # index from sp to return value
	sw      r5  r7 r3       # set return value
	
	addi    r2  r0 $4       # index from sp to return address
	lw      r1  r7 r2       # fetch return address
	addi    r7  r7 $4       # restore stack pointer
	jr      r0  r0 r1       # return

	
