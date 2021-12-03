#define N 8

int state[N];

void memset(void *p, unsigned char c, unsigned int size) {
  unsigned char *ptr = (unsigned char *)p;
  for (unsigned int i=0; i<size; i++)
    ptr[i] = c;
}

void putc(char c) {
  volatile unsigned int *uart_ctrl = (volatile unsigned int *)0x1800000;
  volatile unsigned int *uart_txdata = (volatile unsigned int *)0x1800008;
  while (!(*uart_ctrl & 0x4));
  *uart_txdata = c;
  *uart_ctrl = *uart_ctrl | 0x8;
}

void puts(const char *str) {
  while (*str)
    putc(*str++);
  putc('\r');
  putc('\n');
}

int count_one(int *array, int len) {
  int count = 0;
  for(int i=0; i<len; i++)
    if(array[i])
      count++;
  return count;
}

int is_vaild(int pos) {
  int array[N*2] = {0};
  for(int i=0; i<=pos; i++)
    array[state[i]] = 1;
  if(count_one(array, N*2) != pos + 1)
    return 0;

  memset(array, 0, sizeof(int) * N*2);
  for(int i=0; i<=pos; i++)
    array[state[i] + (N - 1 - i)] = 1;
  if(count_one(array, N*2) != pos + 1)
    return 0;

  memset(array, 0, sizeof(int) * N*2);
  for(int i=0; i<=pos; i++)
    array[state[i] + i] = 1;
  if(count_one(array, N*2) != pos + 1)
    return 0;

  return 1;
}

void show(void) {
  char line[N+1] = {'\0'};
  char board[N+1] = {'\0'};
  memset(line, '-', N);
  memset(board, ' ', N);
  puts(line);
  for(int i=0; i<N; i++) {
    board[state[i]] = 'o';
    puts(board);
    board[state[i]] = ' ';
  }
  puts(line);
}

int iter(int pos) {
  if(pos == N) {
    show();
    return 1;
  } else {
    int total = 0;
    for(int i=0; i<N; i++) {
      state[pos] = i;
      if(is_vaild(pos))
        total += iter(pos + 1);
    }
    return total;
  }
}

static char buf[16];
static const char numchar[] =
  {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
   'a', 'b', 'c', 'd', 'e', 'f' };

void print_int(int val, int base) {
  char *ptr = buf;
  *ptr++ = '\0';
  if(val < 0) {
    putc('-');
    val = -val;
  }
  do {
    *ptr++ = numchar[val%base];
    val /= base;
  } while(val);
  while(*(--ptr))
    putc(*ptr);
}

int main(void) {
  print_int(iter(0), 10);
  return 0;
}
