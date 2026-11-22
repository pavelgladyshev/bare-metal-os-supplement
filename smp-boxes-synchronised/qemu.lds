ENTRY(_start)
SECTIONS {
    . = 0x80000000;
    .init : { *(.init) }
    .text : { *(.text) }
    .data : { *(.data) }
    .bss : { *(.bss COMMON) }
    . = ALIGN(16);
    . += 0x10000;
    __stack_init = .;
}
