const Bus = @import("bus.zig").Bus;

pub const CpuError = error{
    NotYetSupportedOpcode,
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
            0x01 => { // LD BC, u16
                self.registers.bc.parts.c = self.fetch(bus);
                self.registers.bc.parts.b = self.fetch(bus);
                return 12;
            },
            0x02 => { // LD (BC), A
                bus.write(self.registers.bc.value, self.registers.af.parts.a);
                return 8;
            },
            0x03 => { // INC BC
                self.registers.bc.value +%= 1;
                return 8;
            },
            0x04 => { // INC B
                self.incrementRegister(&self.registers.bc.parts.b);
                return 4;
            },
            0x05 => { // DEC B
                self.decrementRegister(&self.registers.bc.parts.b);
                return 4;
            },
            0x06 => { // LD B, u8
                self.registers.bc.parts.b = self.fetch(bus);
                return 8;
            },
            0x07 => { // RLCA
                self.rotateLeftCircular(&self.registers.af.parts.a);
                return 4;
            },
            0x08 => { // LD (u16), SP
                const low = self.fetch(bus);
                const high = self.fetch(bus);
                const address = (@as(u16, high) << 8) | @as(u16, low);

                bus.write(address, @truncate(self.registers.sp));
                bus.write(address +% 1, @truncate(self.registers.sp >> 8));
                return 20;
            },
            0x09 => { // ADD HL,BC
                self.addHL(self.registers.bc.value);
                return 8;
            },
            0x0A => { // LD A, (BC)
                self.registers.af.parts.a = bus.read(self.registers.bc.value);
                return 8;
            },
            0x0B => { // DEC BC
                self.registers.bc.value -%= 1;
                return 8;
            },
            0x0C => { // INC C
                self.incrementRegister(&self.registers.bc.parts.c);
                return 4;
            },
            0x0D => { // DEC C
                self.decrementRegister(&self.registers.bc.parts.c);
                return 4;
            },
            0x0E => { // LD C,u8
                self.registers.bc.parts.c = self.fetch(bus);
                return 8;
            },
            0x0F => { // RRCA
                self.rotateRightCircular(&self.registers.af.parts.a);
                return 4;
            },
            0x10 => { // STOP
                // TODO: Implement STOP when Input implementation needed is done
                _ = self.fetch(bus);
                return CpuError.NotYetSupportedOpcode;
            },
            0x11 => { // LD DE,u16
                self.registers.de.parts.e = self.fetch(bus);
                self.registers.de.parts.d = self.fetch(bus);
                return 12;
            },
            0x12 => { // LD (DE),A
                bus.write(self.registers.de.value, self.registers.af.parts.a);
                return 8;
            },
            0x13 => { // INC DE
                self.registers.de.value +%= 1;
                return 8;
            },
            0x14 => { // INC D
                self.incrementRegister(&self.registers.de.parts.d);
                return 4;
            },
            0x15 => { // DEC D
                self.decrementRegister(&self.registers.de.parts.d);
                return 4;
            },
            0x16 => { // LD D,u8
                self.registers.de.parts.d = self.fetch(bus);
                return 8;
            },
            0x17 => { // RLA
                self.rotateLeftThroughCarry(&self.registers.af.parts.a);
                return 4;
            },
            0x18 => { // JR i8
                const offset: i8 = @bitCast(self.fetch(bus));
                self.applyRelativeOffset(offset);
                return 12;
            },
            0x19 => { // ADD HL,DE
                self.addHL(self.registers.de.value);
                return 8;
            },
            0x1A => { // LD A,(DE)
                self.registers.af.parts.a = bus.read(self.registers.de.value);
                return 8;
            },
            0x1B => { // DEC DE
                self.registers.de.value -%= 1;
                return 8;
            },
            0x1C => { // INC E
                self.incrementRegister(&self.registers.de.parts.e);
                return 4;
            },
            0x1D => { // DEC E
                self.decrementRegister(&self.registers.de.parts.e);
                return 4;
            },
            0x1E => { // LD E,u8
                self.registers.de.parts.e = self.fetch(bus);
                return 8;
            },
            0x1F => { // RRA
                self.rotateRightThroughCarry(&self.registers.af.parts.a);
                return 4;
            },
            0x20 => { // JR NZ, i8
                const offset: i8 = @bitCast(self.fetch(bus));
                return self.jumpRelativeIf(offset, !self.getZeroFlag());
            },
            0x21 => { // LD HL,u16
                self.registers.hl.parts.l = self.fetch(bus);
                self.registers.hl.parts.h = self.fetch(bus);
                return 12;
            },
            0x22 => { // LD (HL+),A
                bus.write(self.registers.hl.value, self.registers.af.parts.a);
                self.registers.hl.value +%= 1;
                return 8;
            },
            0x23 => { // INC HL
                self.registers.hl.value +%= 1;
                return 8;
            },
            0x24 => { // INC H
                self.incrementRegister(&self.registers.hl.parts.h);
                return 4;
            },
            0x25 => { // DEC H
                self.decrementRegister(&self.registers.hl.parts.h);
                return 4;
            },
            0x26 => { // LD H,u8
                self.registers.hl.parts.h = self.fetch(bus);
                return 8;
            },
            0x27 => { // DAA
                self.registers.af.parts.a = self.getDaaValue();
                return 4;
            },
            0x28 => { // JR Z,i8
                const offset: i8 = @bitCast(self.fetch(bus));
                return self.jumpRelativeIf(offset, self.getZeroFlag());
            },
            0x29 => { // ADD HL,HL
                self.addHL(self.registers.hl.value);
                return 8;
            },
            0x2A => { // LD A,(HL+)
                self.registers.af.parts.a = bus.read(self.registers.hl.value);
                self.registers.hl.value +%= 1;
                return 8;
            },
            0x2B => { // DEC HL
                self.registers.hl.value -%= 1;
                return 8;
            },
            0x2C => { // INC L
                self.incrementRegister(&self.registers.hl.parts.l);
                return 4;
            },
            0x2D => { // DEC L
                self.decrementRegister(&self.registers.hl.parts.l);
                return 4;
            },
            0x2E => { // LD L,u8
                self.registers.hl.parts.l = self.fetch(bus);
                return 8;
            },
            0x2F => { // CPL
                self.registers.af.parts.a = ~self.registers.af.parts.a;
                self.setSubtractionFlag(true);
                self.setHalfCarryFlag(true);
                return 4;
            },

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

    fn incrementRegister(self: *Cpu, register: *u8) void {
        const original_value = register.*;
        register.* +%= 1;

        self.setZeroFlag(register.* == 0);
        self.setSubtractionFlag(false);
        self.setHalfCarryFlag((original_value & 0x0F) == 0x0F);
    }

    fn decrementRegister(self: *Cpu, register: *u8) void {
        const original_value = register.*;
        register.* -%= 1;

        self.setZeroFlag(register.* == 0);
        self.setSubtractionFlag(true);
        self.setHalfCarryFlag((original_value & 0x0F) == 0x00);
    }

    fn rotateLeftCircular(self: *Cpu, register: *u8) void {
        const old_bit_seven = (register.* >> 7) & 1;
        register.* = register.* << 1;
        register.* |= @as(u8, old_bit_seven);

        self.setZeroFlag(false);
        self.setSubtractionFlag(false);
        self.setHalfCarryFlag(false);
        self.setCarryFlag(old_bit_seven != 0);
    }

    fn rotateLeftThroughCarry(self: *Cpu, register: *u8) void {
        const old_bit_seven = (register.* >> 7) & 1;
        register.* = register.* << 1;
        register.* |= if (self.getCarryFlag()) @as(u8, 1) else @as(u8, 0);

        self.setZeroFlag(false);
        self.setSubtractionFlag(false);
        self.setHalfCarryFlag(false);
        self.setCarryFlag(old_bit_seven != 0);
    }

    fn rotateRightCircular(self: *Cpu, register: *u8) void {
        const old_bit_zero = register.* & 1;
        register.* = register.* >> 1;
        register.* |= (old_bit_zero << 7);

        self.setZeroFlag(false);
        self.setSubtractionFlag(false);
        self.setHalfCarryFlag(false);
        self.setCarryFlag(old_bit_zero != 0);
    }

    fn rotateRightThroughCarry(self: *Cpu, register: *u8) void {
        const old_bit_zero = register.* & 1;
        register.* = register.* >> 1;
        register.* |= if (self.getCarryFlag()) @as(u8, (1 << 7)) else @as(u8, (0));

        self.setZeroFlag(false);
        self.setSubtractionFlag(false);
        self.setHalfCarryFlag(false);
        self.setCarryFlag(old_bit_zero != 0);
    }

    fn addHL(self: *Cpu, value: u16) void {
        const original_value = self.registers.hl.value;
        self.registers.hl.value +%= value;

        self.setSubtractionFlag(false);
        self.setHalfCarryFlag((original_value & 0x0FFF) + (value & 0x0FFF) > 0x0FFF);
        self.setCarryFlag(@as(u32, original_value) + @as(u32, value) > 0xFFFF);
    }

    fn applyRelativeOffset(self: *Cpu, offset: i8) void {
        const signed_offset = @as(i16, offset);
        const signed_pc = @as(i16, @bitCast(self.registers.pc));

        self.registers.pc = @bitCast(signed_pc +% signed_offset);
    }

    fn jumpRelativeIf(self: *Cpu, offset: i8, condition: bool) u8 {
        if (condition) {
            self.applyRelativeOffset(offset);
            return 12;
        }
        return 8;
    }

    fn getDaaValue(self: *Cpu) u8 {
        const subtract = self.getSubtractionFlag();
        var offset: u8 = 0;
        var should_carry = false;
        var value_a = self.registers.af.parts.a;

        if ((!subtract and ((value_a & 0xF) > 0x09)) or self.getHalfCarryFlag()) {
            offset |= 0x06;
        }

        if ((!subtract and (value_a > 0x99)) or self.getCarryFlag()) {
            offset |= 0x60;
            should_carry = true;
        }

        if (subtract) {
            value_a -%= offset;
        } else {
            value_a +%= offset;
        }

        self.setZeroFlag(value_a == 0);
        self.setHalfCarryFlag(false);
        self.setCarryFlag(should_carry);

        return value_a;
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
            self.registers.af.parts.f &= ~@as(u8, (1 << 7));
        }
    }

    // Flag n
    fn setSubtractionFlag(self: *Cpu, value: bool) void {
        if (value) {
            self.registers.af.parts.f |= (1 << 6);
        } else {
            self.registers.af.parts.f &= ~@as(u8, (1 << 6));
        }
    }

    // Flag h
    fn setHalfCarryFlag(self: *Cpu, value: bool) void {
        if (value) {
            self.registers.af.parts.f |= (1 << 5);
        } else {
            self.registers.af.parts.f &= ~@as(u8, (1 << 5));
        }
    }

    // Flag c
    fn setCarryFlag(self: *Cpu, value: bool) void {
        if (value) {
            self.registers.af.parts.f |= (1 << 4);
        } else {
            self.registers.af.parts.f &= ~@as(u8, (1 << 4));
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
