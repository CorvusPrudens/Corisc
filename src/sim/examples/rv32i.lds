ENTRY(entry)

_estack = 0x00000800;

MEMORY
{
	ROM (RX)      : ORIGIN = 0x00000000, LENGTH = 1K
  SRAM (RWX)    : ORIGIN = 0x00000400, LENGTH = 1K

  APU (W)       : ORIGIN = 0x00030000, LENGTH = 32
}

SECTIONS
{

  .isr_vector :
	{
		. = ALIGN(4);
		KEEP(*(.isr_vector))
		. = ALIGN(4);
	} > ROM

  .preinit_array :
	{
		PROVIDE(__preinit_array_start = .);
		KEEP(*(.preinit_array*))
		PROVIDE(__preinit_array_end = .);
	} > ROM

	.init_array :
	{
		PROVIDE(__init_array_start = .);
		KEEP(*(SORT(.init_array.*)))
		KEEP(*(.init_array*))
		PROVIDE(__init_array_end = .);
	} > ROM

	.fini_array :
	{
		PROVIDE(__fini_array_start = .);
		KEEP(*(.fini_array*))
		KEEP(*(SORT(.fini_array.*)))
		PROVIDE(__fini_array_end = .);
	} > ROM

  .text :
	{
		. = ALIGN(4);
		_stext = .;

		*(.text)
		*(.text*)
		*(.rodata)
		*(.rodata*)
		KEEP(*(.init))
		KEEP(*(.fini))
		. = ALIGN(4);
		_etext = .;

	} > ROM

  .data :
	{
		. = ALIGN(4);
		_sdata = .;

		PROVIDE(__data_start__ = _sdata);
		*(.data)
		*(.data*)
		. = ALIGN(4);
		_edata = .;

		PROVIDE(__data_end__ = _edata);
	} > SRAM AT > ROM

  .sdata :
	{
		. = ALIGN(4);
		_ssdata = .;

		PROVIDE(__sdata_start__ = _sdata);
		*(.sdata)
		*(.sdata*)
		. = ALIGN(4);
		_esdata = .;

		PROVIDE(__sdata_end__ = _esdata);
	} > SRAM AT > ROM

	/* _sidata = LOADADDR(.data); */

	.bss (NOLOAD) :
	{
		. = ALIGN(4);
		_sbss = .;

		PROVIDE(__bss_start__ = _sbss);
		*(.bss)
		*(.bss*)
		*(COMMON)
		. = ALIGN(4);
		_ebss = .;

		PROVIDE(__bss_end__ = _ebss);
	} > SRAM

}