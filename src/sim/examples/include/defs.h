
#ifndef DEFS_H
#define DEFS_H

#include <stddef.h>
#include <stdint.h>

#define OPT_Os __attribute__((optimize("Os")))
#define OPT_O3 __attribute__((optimize("O3")))
#define OPT_O2 __attribute__((optimize("O2")))
#define OPT_O1 __attribute__((optimize("O1")))

#define S_VECTOR_TABLE __attribute__((section(".vector_table")))

// Memory mapped I/O
#define UART *((volatile uint8_t*) 4096)
#define UART_STATUS *((volatile uint8_t*) 4097)

#endif