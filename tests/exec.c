#include <stdio.h>

int main(int argc, char **argv) {
    int i;

    printf("kcapk external executable OK");
    for (i = 1; i < argc; ++i) {
        printf(" %s", argv[i]);
    }
    putchar('\n');

    return 0;
}
