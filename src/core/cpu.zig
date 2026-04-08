const Bus = @import("bus.zig").Bus;

pub const CpuError = error{
    UnknownOpcode,
};

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

    pub fn step(self: *Cpu, bus: *Bus) !u8 {
        const opcode = self.fetch(bus);

        // switch case for opcode decoing for now
        // considering refactoring to something like table[0x0000] in the future
        return switch (opcode) {
            0x00 => 4, // nop/no operation

            else => CpuError.UnknownOpcode,
        };
    }

    fn fetch(self: *Cpu, bus: *Bus) u8 {
        // read the byte at program counter from the bus
        const fetched = bus.read(self.registers.pc);
        // increment program counter
        // make sure that it wraps around if needed
        self.registers.pc +%= 1;
        return fetched;
    }

    fn readU16(bus: *Bus, address: u16) u16 {
        const low = bus.read(address);
        const high = bus.read(address +% 1);

        //Little-endian — least significant byte (low byte) comes first in memory
        return (@as(u16, high) << 8) | @as(u16, low);
    }

    fn push(self: *Cpu, bus: *Bus, register: u16) void {
        const high = @as(u8, @truncate(register >> 8));
        const low = @as(u8, @truncate(register));

        self.registers.sp -%= 1;
        bus.write(self.registers.sp, high);
        self.registers.sp -%= 1;
        bus.write(self.registers.sp, low);
    }

    fn pop(self: *Cpu, bus: *Bus) u16 {
        const low = bus.read(self.registers.sp);
        self.registers.sp +%= 1;
        const high = bus.read(self.registers.sp);
        self.registers.sp +%= 1;

        return (@as(u16, high) << 8) | @as(u16, low);
    }

    // Flag z
    fn getZeroFlag(self: *Cpu) bool {
        return (self.registers.af.parts.f & (1 << 7)) != 0;
    }

    // Flag n
    fn getSubtractionFlag(self: *Cpu) bool {
        return (self.registers.af.parts.f & (1 << 6)) != 0;
    }

    // Flag h
    fn getHalfCarryFlag(self: *Cpu) bool {
        return (self.registers.af.parts.f & (1 << 5)) != 0;
    }

    // Flag c
    fn getCarryFlag(self: *Cpu) bool {
        return (self.registers.af.parts.f & (1 << 4)) != 0;
    }

    // Flag z
    fn setZeroFlag(self: *Cpu, value: bool) void {
        if (value) {
            self.registers.af.parts.f |= (1 << 7);
        } else {
            self.registers.af.parts.f &= ~(1 << 7);
        }
    }

    // Flag n
    fn setSubtractionFlag(self: *Cpu, value: bool) void {
        if (value) {
            self.registers.af.parts.f |= (1 << 6);
        } else {
            self.registers.af.parts.f &= ~(1 << 6);
        }
    }

    // Flag h
    fn setHalfCarryFlag(self: *Cpu, value: bool) void {
        if (value) {
            self.registers.af.parts.f |= (1 << 5);
        } else {
            self.registers.af.parts.f &= ~(1 << 5);
        }
    }

    // Flag c
    fn setCarryFlag(self: *Cpu, value: bool) void {
        if (value) {
            self.registers.af.parts.f |= (1 << 4);
        } else {
            self.registers.af.parts.f &= ~(1 << 4);
        }
    }

    // Cpu State is used for gameboy doctor
    pub fn toCpuState(self: *Cpu, bus: *Bus) CpuState {
        return CpuState{
            .registers = self.registers,
            .pcmem = .{
                bus.read(self.registers.pc),
                bus.read(self.registers.pc +% 1),
                bus.read(self.registers.pc +% 2),
                bus.read(self.registers.pc +% 3),
            },
        };
    }
};

pub const CpuState = struct {
    registers: Registers,
    pcmem: [4]u8,
};
