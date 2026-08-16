// Read a line of bytes from the host, echo it back exactly, and repeat.
// Sending the line "quit" ends the test cleanly instead of echoing it.

#ifndef LINE_MAX
#define LINE_MAX 128 // includes the terminating '\0'; excess bytes on an overlong line are dropped
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"

// Block until a full line (terminated by '\r' or '\n', not included in buf) has been read.
// Returns the line length, not counting the null terminator.
static unsigned read_line(char *buf, unsigned max) {
    unsigned len = 0;
    for (;;) {
        uint8_t c = uart_read(&__base_uart);
        if (c == '\r' || c == '\n') break;
        if (len + 1 < max) buf[len++] = (char)c;
    }
    buf[len] = '\0';
    return len;
}

int main(void) {
    lagd_chip_init();

    printf("Listening on UART...\r\n");

    char line[LINE_MAX];
    for (;;) {
        unsigned len = read_line(line, LINE_MAX);
        if (len == 4 && line[0] == 'q' && line[1] == 'u' && line[2] == 'i' && line[3] == 't') break;
        printf("%s\r\n", line);
    }

    lagd_chip_finish();
    return 0;
}
