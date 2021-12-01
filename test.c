int fib(int n) {
  if (n <= 1) return 1; else return fib(n-2) + fib(n-1);
}

void main() {
  volatile unsigned int *led = (volatile unsigned int *)0x1000000;
  *led = 0;
  while (1) {
    for (int i=0; i<2400000; i++);
    int prev = *led;
    *led = prev==8 ? 0 : prev+1;
  }
}
