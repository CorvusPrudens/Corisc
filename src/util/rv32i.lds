ENTRY(entry)

_estack = 0x00030000;

MEMORY
{
	GENERAL (RW)   : ORIGIN = 0x00001000, LENGTH = 64
	GPU (RW)       : ORIGIN = 0x00002000, LENGTH = 8K + 4
	APU (RW)       : ORIGIN = 0x00005000, LENGTH = 23
	VRC6_1 (RW)    : ORIGIN = 0x00009000, LENGTH = 4
	VRC6_2 (RW)    : ORIGIN = 0x0000A000, LENGTH = 4
	VRC6_3 (RW)    : ORIGIN = 0x0000B000, LENGTH = 4

  PROGMEM (RWX)  : ORIGIN = 0x00010000, LENGTH = 64K
  SRAM (RWX)     : ORIGIN = 0x00020000, LENGTH = 64K
}

SECTIONS
{
	.general (NOLOAD) :
	{
		_sgeneral = .;
		. = ALIGN(4);
		KEEP(*(.general))
		. = ALIGN(4);
		_egeneral = .;
	} > GENERAL

	.gpu (NOLOAD) :
	{
		_sgpu = .;
		. = ALIGN(4);
		KEEP(*(.gpu))
		. = ALIGN(4);
		_egpu = .;
	} > GPU

	.apu (NOLOAD) :
	{
		_sapu = .;
		. = ALIGN(4);
		KEEP(*(.apu))
		. = ALIGN(4);
		_eapu = .;
	} > APU

	.vrc6_1 (NOLOAD) :
	{
		_svrc6_1 = .;
		. = ALIGN(4);
		KEEP(*(.vrc6_1))
		. = ALIGN(4);
		_evrc6_1 = .;
	} > VRC6_1

	.vrc6_2 (NOLOAD) :
	{
		_svrc6_2 = .;
		. = ALIGN(4);
		KEEP(*(.vrc6_2))
		. = ALIGN(4);
		_evrc6_2 = .;
	} > VRC6_2

	.vrc6_3 (NOLOAD) :
	{
		_svrc6_3 = .;
		. = ALIGN(4);
		KEEP(*(.vrc6_3))
		. = ALIGN(4);
		_evrc6_3 = .;
	} > VRC6_3

/*
  .preinit_array :
	{
		PROVIDE(__preinit_array_start = .);
		KEEP(*(.preinit_array*))
		PROVIDE(__preinit_array_end = .);
	} > PROGMEM

	.init_array :
	{
		PROVIDE(__init_array_start = .);
		KEEP(*(SORT(.init_array.*)))
		KEEP(*(.init_array*))
		PROVIDE(__init_array_end = .);
	} > PROGMEM

	.fini_array :
	{
		PROVIDE(__fini_array_start = .);
		KEEP(*(.fini_array*))
		KEEP(*(SORT(.fini_array.*)))
		PROVIDE(__fini_array_end = .);
	} > PROGMEM
*/

  .text :
	{
		. = ALIGN(4);
		_stext = .;
		KEEP(*(.vector_table))
		*(.text)
		*(.text*)
		*(.progmem)
		*(.progmem*)
		*(.srodata)
		*(.srodata*)
		*(.rodata)
		*(.rodata*)
		KEEP(*(.init))
		KEEP(*(.fini))
		. = ALIGN(4);
		_etext = .;

	} > PROGMEM

  .data :
	{
		. = ALIGN(4);
		_sdata = .;

		PROVIDE(__data_start__ = _sdata);
		*(.sdata)
		*(.sdata*)
		*(.data)
		*(.data*)
		. = ALIGN(4);
		_edata = .;

		PROVIDE(__data_end__ = _edata);
	} > SRAM AT > PROGMEM

	_sidata = LOADADDR(.data);
	
	.bss (NOLOAD) :
	{
		. = ALIGN(4);
		_sbss = .;

		PROVIDE(__bss_start__ = _sbss);
		*(.sbss)
		*(.sbss*)
		*(.bss)
		*(.bss*)
		*(COMMON)
		. = ALIGN(4);
		_ebss = .;

		PROVIDE(__bss_end__ = _ebss);
	} > SRAM

	.sram (NOLOAD) :
	{
		. = ALIGN(4);
		KEEP(*(.sram))
		. = ALIGN(4);
	} > SRAM

}