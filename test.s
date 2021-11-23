addi x11, x0, 3
addi x12, x0, 4
addi x13, x0, 0
L1:
beq x0, x11, L2
addi x11, x11, -1
add x13, x13, x12
j L1
L2:
ecall
