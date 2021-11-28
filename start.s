.section .text.init

.global _start
_start:
  lui sp, 0x8000
  call main
  j .
