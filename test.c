void main() {
  volatile unsigned int *led = (volatile unsigned int *)0x1000000;
  *led = 1;
  while (1) {
    for (int i=0; i<24000000; i++);
    *led = ~(*led);
  }
}
