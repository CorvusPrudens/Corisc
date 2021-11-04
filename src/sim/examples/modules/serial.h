#ifndef SERIAL_H
#define SERIAL_H

#include "defs.h"

void write_string(const char* str);
uint8_t uart_tx_full();
uint8_t uart_tx_empty();
uint8_t uart_rx_full();
uint8_t uart_rx_empty();

#endif // SERIAL_H