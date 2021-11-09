.align	2
.globl	main
.type	main, @function
main:
  li   a1, 100
loop:
  addi a0, a0, 20
  sw   a0, 0(a1)
  beq  a0, a1, end
  add  x0, x0, x0
  j loop

end:
  j end
