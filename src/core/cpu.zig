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

pub const Cpu = struct {
    registers: Registers,
    // IME: interupt master enable flag
    ime: bool,

    pub fn init() Cpu {}

    fn resetRegisters(self: *Cpu) void {
        // TODO: initial value for the f register depends on the checksum for now it is hardcodedas the non-zero checksum fix this when cartridge is implemented
        self.registers.af.value = 0x01B0;
        self.registers.bc.value = 0x0013;
        self.registers.de.value = 0x00D8;
        self.registers.hl.value = 0x014D;
        self.registers.sp = 0xFFFE;
        self.registers.pc = 0x0100;
    }
};

pub const CpuState = struct {
    registers: Registers,
    pcmem: [4]u8,
};
