OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x0;
  .text.init : { *(.text.init) }
  .text : { *(.text) }
  . = 0x800000;
  .rodata : { *(.rodata) }
  . = ALIGN(0x4);
  .data : { *(.data) }
  . = ALIGN(0x4);
  .bss : { *(.bss) }
  _end = .;
}

