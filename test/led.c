void main() {
  volatile unsigned int *led = (volatile unsigned int *)0x1000000;
  *led = 0;
  while (1) {
    for (volatile int i=0; i<2400000; i++);
    int prev = *led;
    *led = prev==8 ? 0 : prev+1;
  }
}
