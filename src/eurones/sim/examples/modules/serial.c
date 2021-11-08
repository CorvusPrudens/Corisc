#include "serial.h"
#include "defs.h"

#define TX_FULL  0b0001
#define TX_EMPTY 0b0010
#define RX_FULL  0b0100
#define RX_EMPTY 0b1000

void OPT_Os write_string(const char* str)
{
  for (const char* i = str; *i != 0; i++)
    UART = *i;
  UART = (uint8_t) 0;
}

inline uint8_t OPT_Os uart_tx_full()
{
  return (UART_STATUS & TX_FULL) > 0;
}
inline uint8_t OPT_Os uart_tx_empty()
{
  return (UART_STATUS & TX_EMPTY) > 0;
}
inline uint8_t OPT_Os uart_rx_full()
{
  return (UART_STATUS & RX_FULL) > 0;
}
inline uint8_t OPT_Os uart_rx_empty()
{
  return (UART_STATUS & RX_EMPTY) > 0;
}