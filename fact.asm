# fact(int n)
        .align
fact:   addi r7 r7 $-4 # allocate stack space
        addi r2 r0 $4  # index from sp to return address field
        sw   r1 r7 r2  # save return address

        addi r2 r0 $8  # index from sp to n
        lw   r3 r7 r2  # r3 = n
        addi r4 r0 $2  # index from sp to max
        addi r8 r3 $-1 # r8 = n - 1
        mul  r5 r3 r8  # fact = n * (n-1) saved in r5      

        cmp  r1 r0 r3  # compare 0 and n
        be   :done     # if n = 0 done
        add  r6 r6 r5  # incremented fact

done:  lw   r6 r7 r3  # set return value
       addi r2 r0 $4  # index from sp to return address
       lw   r1 r7 r2  # fetch return address
       addi r7 r7 $4  # restore stack pointer
       jr   r0 r0 r1  # return to return address