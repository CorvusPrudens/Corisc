ENTRY(entry)

_estack = 0x00030000;

MEMORY
{
	BOOTLOADER (RX): ORIGIN = 0x00000000, LENGTH = 1K
	GENERAL (RW)   : ORIGIN = 0x00001000, LENGTH = 64
	GPU (RW)       : ORIGIN = 0x00002000, LENGTH = 1K
	APU (RW)       : ORIGIN = 0x00004000, LENGTH = 23
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
	}

	.gpu (NOLOAD) :
	{
		_sgpu = .;
		. = ALIGN(4);
		KEEP(*(.gpu))
		. = ALIGN(4);
		_egpu = .;
	}

	.apu (NOLOAD) :
	{
		_sapu = .;
		. = ALIGN(4);
		KEEP(*(.apu))
		. = ALIGN(4);
		_eapu = .;
	}

	.vrc6_1 (NOLOAD) :
	{
		_svrc6_1 = .;
		. = ALIGN(4);
		KEEP(*(.vrc6_1))
		. = ALIGN(4);
		_evrc6_1 = .;
	}

	.vrc6_2 (NOLOAD) :
	{
		_svrc6_2 = .;
		. = ALIGN(4);
		KEEP(*(.vrc6_2))
		. = ALIGN(4);
		_evrc6_2 = .;
	}

	.vrc6_3 (NOLOAD) :
	{
		_svrc6_3 = .;
		. = ALIGN(4);
		KEEP(*(.vrc6_3))
		. = ALIGN(4);
		_evrc6_3 = .;
	}

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

	.vector_table :
	{
		. = ALIGN(4);
		KEEP(*(.vector_table))
		. = ALIGN(4);
	} > BOOTLOADER

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

	} > BOOTLOADER

	.bootloader :
	{
		_sboot = .;
		. = ALIGN(4);
		*(.bootloader)
		*(.bootloader*)
		. = ALIGN(4);
		_eboot = .;
	} > BOOTLOADER

	.bootdata :
	{
		_sbdata = .;
		. = ALIGN(4);
		KEEP(*(.bootdata))
		. = ALIGN(4);
		_ebdata = .;
	} > BOOTLOADER

	.progmem (NOLOAD) :
	{
		. = ALIGN(4);
		KEEP(*(.progmem))
		. = ALIGN(4);
	} > PROGMEM

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
	} > SRAM AT > BOOTLOADER

	_sisdata = LOADADDR(.sdata);

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
	} > SRAM AT > BOOTLOADER

	_sidata = LOADADDR(.data);

	.sbss (NOLOAD) :
	{
		. = ALIGN(4);
		_ssbss = .;

		PROVIDE(__sbss_start__ = _ssbss);
		*(.sbss)
		*(.sbss*)
		*(COMMON)
		. = ALIGN(4);
		_esbss = .;

		PROVIDE(__sbss_end__ = _esbss);
	} > SRAM

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

	.sram (NOLOAD) :
	{
		. = ALIGN(4);
		KEEP(*(.sram))
		. = ALIGN(4);
	} > SRAM

}