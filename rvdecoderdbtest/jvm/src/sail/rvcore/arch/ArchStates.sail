// PC
register PC       : xlenbits
register nextPC   : xlenbits

// regfile

register x1  : regtype
register x2  : regtype
register x3  : regtype
register x4  : regtype
register x5  : regtype
register x6  : regtype
register x7  : regtype
register x8  : regtype
register x9  : regtype
register x10 : regtype
register x11 : regtype
register x12 : regtype
register x13 : regtype
register x14 : regtype
register x15 : regtype
register x16 : regtype
register x17 : regtype
register x18 : regtype
register x19 : regtype
register x20 : regtype
register x21 : regtype
register x22 : regtype
register x23 : regtype
register x24 : regtype
register x25 : regtype
register x26 : regtype
register x27 : regtype
register x28 : regtype
register x29 : regtype
register x30 : regtype
register x31 : regtype

// state
register cur_privilege : Privilege
register instbits : xlenbits
// csr
register mie				: MIE
register mip				: MIP
register mideleg				: MIDELEG
register mstatus				: MSTATUS
register mtvec				: MTVEC
register mcause				: MCAUSE
register menvcfg				: MENVCFG
register senvcfg				: SENVCFG
register satp				: SATP
register misa				: MISA
register mtval				: MTVAL
register mepc				: MEPC
register stvec				: STVEC
register sepc				: SEPC
register scause				: SCAUSE
register stval				: STVAL
register medeleg				: MEDELEG
