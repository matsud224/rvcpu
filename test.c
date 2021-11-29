void main() {
  volatile unsigned int *ram = (volatile unsigned int *)0x804000;
  volatile unsigned int *led = (volatile unsigned int *)0x1000000;
  ram[0] = 0x12345678;
  ram[1] = 0xff00ff00;
  ram[2] = 0x00ff00ff;
  *led = 1;
}
