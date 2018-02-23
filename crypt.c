#include <stdio.h>
#include <crypt.h>

int main(int argc, char **argv) {
  char *cr = crypt(argv[1], argv[1]);
  printf("%s", cr);
}
