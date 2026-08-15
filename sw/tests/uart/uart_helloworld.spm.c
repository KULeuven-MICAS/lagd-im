// Minimal chip bring-up smoke test:
//  1) lagd_chip_init() brings up the UART
//  2) printf sends "Hello World!" over it
//  3) lagd_chip_finish() flushes and reports the result.

#include "printf.h"
#include "lagd_chip.h"

int main(void) {
    lagd_chip_init();
    printf("Hello World!\r\n");
    lagd_chip_finish();
    return 0;
}
