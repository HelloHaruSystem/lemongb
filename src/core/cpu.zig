const Bus = @import("bus.zig").Bus;

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

    pub fn init() Cpu {
        var cpu = Cpu{ .registers = undefined, .ime = false };
        cpu.resetRegisters();
        return cpu;
    }

    fn resetRegisters(self: *Cpu) void {
        // TODO: initial value for the f register depends on the checksum for now it is hardcoded as the non-zero checksum fix this when cartridge is implemented
        self.registers.af.value = 0x01B0;
        self.registers.bc.value = 0x0013;
        self.registers.de.value = 0x00D8;
        self.registers.hl.value = 0x014D;
        self.registers.sp = 0xFFFE;
        self.registers.pc = 0x0100;
    }

    pub fn step(self: *Cpu, bus: *Bus) u8 {
        // read the byte at program counter from the bus
        const opcode = bus.read(self.registers.pc);
        // increment program counter
        // make sure that it wraps around if needed
        self.registers.pc +%= 1;

        // switch case for opcode decoing for now
        // considering refactoring to something like table[0x0000] in the future
        return switch (opcode) {
            0x00 => 4, // nop/no operation

            else => unreachable,
        };
    }
};

pub const CpuState = struct {
    registers: Registers,
    pcmem: [4]u8,
};
