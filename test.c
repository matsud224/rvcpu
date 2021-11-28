int a[10];
int b[10] = {10,20,30,40,50,40,30,20,10};

void main() {
  for (int i=0; i<10; i++)
    a[i] = i*i;
  int sum = 0;
  a[3] = a[4] / 6;
  for (int i=0; i<10; i++)
    sum += a[i] * b[i];
  volatile int *p = (volatile int *)0x200000;
  *p = sum;
}
