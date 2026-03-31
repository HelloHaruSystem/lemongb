const AF = packed union {
    value: u16,
    parts: packed struct { f: u8, a: u8 },
};

const BC = packed union {
    value: u16,
    parts: packed struct { c: u8, b: u8 },
};

const DE = packed union {
    value: u16,
    parts: packed struct { e: u8, d: u8 },
};

const HL = packed union {
    value: u16,
    parts: packed struct { l: u8, h: u8 },
};

pub const Registers = struct {
    af: AF,
    bc: BC,
    de: DE,
    hl: HL,
    // stack pointer
    sp: u16,
    // program counter
    pc: u16,
};

pub const CpuState = struct {
    registers: Registers,
    pcmem: [4]u8,
};
