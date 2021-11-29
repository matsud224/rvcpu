.section .text.init

.global _start
_start:
  lui sp, 0x808
  call main
  j .
