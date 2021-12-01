void uart_putc(char c) {
  volatile unsigned int *uart_ctrl = (volatile unsigned int *)0x1800000;
  volatile unsigned int *uart_txdata = (volatile unsigned int *)0x1800008;
  while (!(*uart_ctrl & 0x4));
  *uart_txdata = c;
  *uart_ctrl = *uart_ctrl | 0x8;
}

void uart_puts(const char *str) {
  while (*str)
    uart_putc(*str++);
}

void main() {
  uart_puts("hello, world!");
}
