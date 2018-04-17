prologue:  addi	  r1  r0  0x0f    # set up stack pointer register
	   shftl  r7  r1  $12
           # we could pass argc/argv here, if we had them
	   call   r1  main
	   stop
	