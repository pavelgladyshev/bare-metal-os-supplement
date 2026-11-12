ENTRY(_start)
SECTIONS {
    . = 0x80000000;
    .init : { *(.init) }
    .text : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) *(.sdata*) }
    .bss : { *(.bss*) *(.sbss*) *(COMMON) }
    . = ALIGN(16);
    . += 0x2000;
    __stack_top = .;
}
