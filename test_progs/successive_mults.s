
	data = 0x1000
	li	x2, data
    addi x4, x0, 3
    mul x5, x4, x4
    mul x5, x4, x4
    beq x5, x5, label
    mul x7, x6, x4
	lw	x8, 0x0(x2)
label:
	lw	x8, 0x0(x2)
    mul x8, x4, x4
    mul x9, x4, x4
    wfi
