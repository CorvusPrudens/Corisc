
#ifndef DEFS_H
#define DEFS_H

#include <stddef.h>
#include <stdint.h>

#define OPT_Os __attribute__((optimize("Os")))
#define OPT_O3 __attribute__((optimize("O3")))
#define OPT_O2 __attribute__((optimize("O2")))
#define OPT_O1 __attribute__((optimize("O1")))

#define INTERRUPT __attribute__((interrupt))

#define MEM_BOOTLOADER __attribute__((section(".bootloader")))
#define MEM_GENERAL __attribute__((section(".general")))
#define MEM_GPU __attribute__((section(".gpu")))
#define MEM_APU __attribute__((section(".apu")))
#define MEM_VRC6_1 __attribute__((section(".vrc6_1")))
#define MEM_VRC6_2 __attribute__((section(".vrc6_2")))
#define MEM_VRC6_3 __attribute__((section(".vrc6_3")))
#define MEM_PROGMEM __attribute__((section(".progmem")))
#define MEM_SRAM __attribute__((section(".sram")))
#define MEM_VECTOR_TABLE __attribute__((section(".vector_table")))

#define MEM_PROGMEM_ADDR (0x00010000)
#define MEM_SRAM_ADDR (0x00020000)

// Memory mapped I/O
// TODO -- this should probably be based on the linker or something
#define UART *((volatile uint8_t*) 0x00001000)
#define UART_STATUS *((volatile uint8_t*) 0x00001001)

#define FLASH_DATA *((volatile uint16_t*) 0x00001002)
#define FLASH_PAGE *((volatile uint16_t*) 0x00001004)
#define FLASH_STATUS *((volatile uint16_t*) 0x00001006)
#define FLASH_PAGE_LEN 256

#define INTERRUPT_VECTOR *((volatile uint16_t*) 0x00001008)
#define INTERRUPT_MASK   *((volatile uint16_t*) 0x0000100A)

#endif