# fact(int n)
        .align
fact:   addi r7 r7 $-4 # allocate stack space
        addi r2 r0 $4  # index from sp to return address field
        sw   r1 r7 r2  # save return address

        addi r2 r0 $8  # index from sp to n
        lw   r3 r7 r2  # r3 = n
        addi r4 r0 $2  # index from sp to fact

        addi r6 r3 $-1 # r8 = n - 1

top:    mul  r5 r5 r6  # fact = n * (n-1) saved in r5  
        cmp  r1 $1 r6  # compare 1 and n
        be   :done     # r5 = 24     
        addi r6 r6 $-1 # r3 = r3 - 1
        # add  r6 r6 r5  # incremented fact
        blt: top

  # lw   r6 r7 r5  # set return value        last one r3
       # addi r2 r0 $-8  # index from sp to return address
        # lw   r1 r7 r2  # fetch return address
       # addi r7 r7 $4  # restore stack pointer
       # jr   r0 r0 r1  # return to return address
done:      printr r5
       addi r1 r0 $8
       sw r5 r3  r1
       addi r2 r0 $4
       lw r1 r7 r2
       addi r7 r7 $4
       jr r0 r0 r1