const std = @import("std");
const Cpu = @import("cpu.zig").Cpu;
const Bus = @import("bus.zig").Bus;

// ---------------------------------------------------------------------------
// AI generated!
// Test Harness
// ---------------------------------------------------------------------------
// Wraps a Cpu + Bus pair. Lets each test:
//   1. Write raw bytes into ROM (starting at 0x0100 where PC begins)
//   2. Run one or more steps
//   3. Inspect registers and flags
//
// Design goals:
//   - Tests must NOT pass just because of a particular implementation choice.
//     Every assertion is derived from the Game Boy hardware specification.
//   - Edge cases are first-class: boundary values, flag interactions, wrap-around.
//   - The harness itself has no knowledge of opcode encodings beyond what it
//     writes into memory — the CPU under test does all decoding.

const Harness = struct {
    cpu: Cpu,
    bus: Bus,

    /// Create a fresh harness. Registers are in the post-boot-ROM DMG state.
    pub fn init() Harness {
        return .{
            .cpu = Cpu.init(),
            .bus = Bus.init(),
        };
    }

    /// Write a sequence of bytes into ROM starting at 0x0100 (where PC starts).
    pub fn load(self: *Harness, bytes: []const u8) void {
        for (bytes, 0..) |byte, i| {
            // Bypass the read-only guard by writing directly to memory.
            // This is intentional: we are loading test ROM data.
            self.bus.memory[0x0100 + i] = byte;
        }
    }

    /// Execute exactly one instruction and return the T-cycle count.
    pub fn step(self: *Harness) !u8 {
        return self.cpu.step(&self.bus);
    }

    /// Execute N instructions.
    pub fn stepN(self: *Harness, n: usize) !void {
        for (0..n) |_| _ = try self.step();
    }

    // -- Register accessors --------------------------------------------------

    pub fn regA(self: *Harness) u8 {
        return self.cpu.registers.af.parts.a;
    }
    pub fn regF(self: *Harness) u8 {
        return self.cpu.registers.af.parts.f;
    }
    pub fn regB(self: *Harness) u8 {
        return self.cpu.registers.bc.parts.b;
    }
    pub fn regC(self: *Harness) u8 {
        return self.cpu.registers.bc.parts.c;
    }
    pub fn regD(self: *Harness) u8 {
        return self.cpu.registers.de.parts.d;
    }
    pub fn regE(self: *Harness) u8 {
        return self.cpu.registers.de.parts.e;
    }
    pub fn regH(self: *Harness) u8 {
        return self.cpu.registers.hl.parts.h;
    }
    pub fn regL(self: *Harness) u8 {
        return self.cpu.registers.hl.parts.l;
    }
    pub fn regBC(self: *Harness) u16 {
        return self.cpu.registers.bc.value;
    }
    pub fn regDE(self: *Harness) u16 {
        return self.cpu.registers.de.value;
    }
    pub fn regHL(self: *Harness) u16 {
        return self.cpu.registers.hl.value;
    }
    pub fn regSP(self: *Harness) u16 {
        return self.cpu.registers.sp;
    }
    pub fn regPC(self: *Harness) u16 {
        return self.cpu.registers.pc;
    }

    // -- Flag accessors (derived from F register bits) -----------------------
    // Bit 7 = Z, Bit 6 = N, Bit 5 = H, Bit 4 = C

    pub fn flagZ(self: *Harness) bool {
        return (self.regF() & (1 << 7)) != 0;
    }
    pub fn flagN(self: *Harness) bool {
        return (self.regF() & (1 << 6)) != 0;
    }
    pub fn flagH(self: *Harness) bool {
        return (self.regF() & (1 << 5)) != 0;
    }
    pub fn flagC(self: *Harness) bool {
        return (self.regF() & (1 << 4)) != 0;
    }

    // -- Helpers -------------------------------------------------------------

    /// Directly set a register pair value (for test setup).
    pub fn setBC(self: *Harness, v: u16) void {
        self.cpu.registers.bc.value = v;
    }
    pub fn setDE(self: *Harness, v: u16) void {
        self.cpu.registers.de.value = v;
    }
    pub fn setHL(self: *Harness, v: u16) void {
        self.cpu.registers.hl.value = v;
    }
    pub fn setSP(self: *Harness, v: u16) void {
        self.cpu.registers.sp = v;
    }
    pub fn setA(self: *Harness, v: u8) void {
        self.cpu.registers.af.parts.a = v;
    }
    pub fn setB(self: *Harness, v: u8) void {
        self.cpu.registers.bc.parts.b = v;
    }
    pub fn setC(self: *Harness, v: u8) void {
        self.cpu.registers.bc.parts.c = v;
    }
    pub fn setD(self: *Harness, v: u8) void {
        self.cpu.registers.de.parts.d = v;
    }
    pub fn setE(self: *Harness, v: u8) void {
        self.cpu.registers.de.parts.e = v;
    }

    /// Write a byte to an arbitrary bus address (for memory-operand tests).
    pub fn writeMem(self: *Harness, addr: u16, val: u8) void {
        self.bus.memory[addr] = val;
    }

    /// Read a byte from an arbitrary bus address.
    pub fn readMem(self: *Harness, addr: u16) u8 {
        return self.bus.memory[addr];
    }
};

// ---------------------------------------------------------------------------
// 0x00  NOP
// ---------------------------------------------------------------------------

test "0x00 NOP: consumes 4 T-cycles and advances PC by 1" {
    var h = Harness.init();
    h.load(&.{0x00});
    const pc_before = h.regPC();
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
    try std.testing.expectEqual(pc_before + 1, h.regPC());
}

test "0x00 NOP: does not alter any register" {
    var h = Harness.init();
    h.load(&.{0x00});
    const a = h.regA();
    const f = h.regF();
    const bc = h.regBC();
    const de = h.regDE();
    const hl = h.regHL();
    const sp = h.regSP();
    _ = try h.step();
    try std.testing.expectEqual(a, h.regA());
    try std.testing.expectEqual(f, h.regF());
    try std.testing.expectEqual(bc, h.regBC());
    try std.testing.expectEqual(de, h.regDE());
    try std.testing.expectEqual(hl, h.regHL());
    try std.testing.expectEqual(sp, h.regSP());
}

// ---------------------------------------------------------------------------
// 0x01  LD BC, u16
// ---------------------------------------------------------------------------

test "0x01 LD BC,u16: loads immediate little-endian u16 into BC" {
    var h = Harness.init();
    // 0x01 lo hi  ->  BC = (hi << 8) | lo
    h.load(&.{ 0x01, 0x34, 0x12 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x1234), h.regBC());
}

test "0x01 LD BC,u16: low byte goes into C, high byte into B" {
    var h = Harness.init();
    h.load(&.{ 0x01, 0xAB, 0xCD });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regC());
    try std.testing.expectEqual(@as(u8, 0xCD), h.regB());
}

test "0x01 LD BC,u16: consumes 12 T-cycles and advances PC by 3" {
    var h = Harness.init();
    h.load(&.{ 0x01, 0x00, 0x00 });
    const pc_before = h.regPC();
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 12), cycles);
    try std.testing.expectEqual(pc_before + 3, h.regPC());
}

test "0x01 LD BC,u16: does not affect flags" {
    var h = Harness.init();
    h.load(&.{ 0x01, 0xFF, 0xFF });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x01 LD BC,u16: edge case 0x0000" {
    var h = Harness.init();
    h.load(&.{ 0x01, 0x00, 0x00 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0000), h.regBC());
}

test "0x01 LD BC,u16: edge case 0xFFFF" {
    var h = Harness.init();
    h.load(&.{ 0x01, 0xFF, 0xFF });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), h.regBC());
}

// ---------------------------------------------------------------------------
// 0x02  LD (BC), A
// ---------------------------------------------------------------------------

test "0x02 LD (BC),A: writes A to memory address in BC" {
    var h = Harness.init();
    h.setBC(0xC000); // work RAM — writable
    h.setA(0x42);
    h.load(&.{0x02});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x42), h.readMem(0xC000));
}

test "0x02 LD (BC),A: consumes 8 T-cycles" {
    var h = Harness.init();
    h.setBC(0xC000);
    h.setA(0x01);
    h.load(&.{0x02});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

test "0x02 LD (BC),A: does not affect flags" {
    var h = Harness.init();
    h.setBC(0xC000);
    h.setA(0xFF);
    h.load(&.{0x02});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x02 LD (BC),A: does not modify BC" {
    var h = Harness.init();
    h.setBC(0xC000);
    h.setA(0x01);
    h.load(&.{0x02});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xC000), h.regBC());
}

// ---------------------------------------------------------------------------
// 0x03  INC BC
// ---------------------------------------------------------------------------

test "0x03 INC BC: increments BC by 1" {
    var h = Harness.init();
    h.setBC(0x0000);
    h.load(&.{0x03});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0001), h.regBC());
}

test "0x03 INC BC: wraps from 0xFFFF to 0x0000" {
    var h = Harness.init();
    h.setBC(0xFFFF);
    h.load(&.{0x03});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0000), h.regBC());
}

test "0x03 INC BC: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x03});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

test "0x03 INC BC: does not affect flags" {
    var h = Harness.init();
    h.setBC(0xFFFF); // worst case — would set flags if it were 8-bit
    h.load(&.{0x03});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x04  INC B
// ---------------------------------------------------------------------------

test "0x04 INC B: increments B by 1" {
    var h = Harness.init();
    h.setB(0x00);
    h.load(&.{0x04});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x01), h.regB());
}

test "0x04 INC B: sets Z when result is 0x00 (wrap from 0xFF)" {
    var h = Harness.init();
    h.setB(0xFF);
    h.load(&.{0x04});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x00), h.regB());
    try std.testing.expect(h.flagZ());
}

test "0x04 INC B: clears Z when result is non-zero" {
    var h = Harness.init();
    h.setB(0x00);
    h.load(&.{0x04});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x04 INC B: clears N flag" {
    var h = Harness.init();
    h.setB(0x10);
    h.load(&.{0x04});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x04 INC B: sets H when lower nibble wraps (0x0F -> 0x10)" {
    var h = Harness.init();
    h.setB(0x0F);
    h.load(&.{0x04});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x04 INC B: clears H when lower nibble does not wrap" {
    var h = Harness.init();
    h.setB(0x00);
    h.load(&.{0x04});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x04 INC B: does not affect C flag" {
    var h = Harness.init();
    // Force C set before the instruction
    h.cpu.registers.af.parts.f |= (1 << 4);
    h.setB(0xFF);
    h.load(&.{0x04});
    _ = try h.step();
    try std.testing.expect(h.flagC()); // C must be unchanged
}

test "0x04 INC B: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x04});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x05  DEC B
// ---------------------------------------------------------------------------

test "0x05 DEC B: decrements B by 1" {
    var h = Harness.init();
    h.setB(0x10);
    h.load(&.{0x05});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x0F), h.regB());
}

test "0x05 DEC B: wraps from 0x00 to 0xFF" {
    var h = Harness.init();
    h.setB(0x00);
    h.load(&.{0x05});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xFF), h.regB());
}

test "0x05 DEC B: sets Z when result is 0x00" {
    var h = Harness.init();
    h.setB(0x01);
    h.load(&.{0x05});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x05 DEC B: clears Z when result is non-zero" {
    var h = Harness.init();
    h.setB(0x05);
    h.load(&.{0x05});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x05 DEC B: sets N flag" {
    var h = Harness.init();
    h.setB(0x10);
    h.load(&.{0x05});
    _ = try h.step();
    try std.testing.expect(h.flagN());
}

test "0x05 DEC B: sets H when lower nibble borrows (0x10 -> 0x0F)" {
    var h = Harness.init();
    h.setB(0x10);
    h.load(&.{0x05});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x05 DEC B: clears H when no borrow from upper nibble" {
    var h = Harness.init();
    h.setB(0x0F);
    h.load(&.{0x05});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x05 DEC B: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.setB(0x00);
    h.load(&.{0x05});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x05 DEC B: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x05});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x06  LD B, u8
// ---------------------------------------------------------------------------

test "0x06 LD B,u8: loads immediate byte into B" {
    var h = Harness.init();
    h.load(&.{ 0x06, 0xBE });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xBE), h.regB());
}

test "0x06 LD B,u8: edge case 0x00" {
    var h = Harness.init();
    h.load(&.{ 0x06, 0x00 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x00), h.regB());
}

test "0x06 LD B,u8: edge case 0xFF" {
    var h = Harness.init();
    h.load(&.{ 0x06, 0xFF });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xFF), h.regB());
}

test "0x06 LD B,u8: consumes 8 T-cycles and advances PC by 2" {
    var h = Harness.init();
    h.load(&.{ 0x06, 0x00 });
    const pc_before = h.regPC();
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
    try std.testing.expectEqual(pc_before + 2, h.regPC());
}

test "0x06 LD B,u8: does not affect flags" {
    var h = Harness.init();
    h.load(&.{ 0x06, 0xFF });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x07  RLCA
// ---------------------------------------------------------------------------

test "0x07 RLCA: bit 7 wraps into bit 0" {
    var h = Harness.init();
    h.setA(0b10000000); // bit 7 set, all others clear
    h.load(&.{0x07});
    _ = try h.step();
    // after rotate left: bit 7 goes to bit 0 -> 0b00000001
    try std.testing.expectEqual(@as(u8, 0b00000001), h.regA());
}

test "0x07 RLCA: bit 7 is copied into C flag" {
    var h = Harness.init();
    h.setA(0b10000001);
    h.load(&.{0x07});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x07 RLCA: C flag cleared when bit 7 was 0" {
    var h = Harness.init();
    h.setA(0b01000000);
    h.load(&.{0x07});
    _ = try h.step();
    try std.testing.expect(!h.flagC());
}

test "0x07 RLCA: Z flag always cleared" {
    var h = Harness.init();
    // Even if result is 0x00 (impossible for RLCA since bit wraps), Z=0
    h.setA(0x00);
    h.load(&.{0x07});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x07 RLCA: N flag always cleared" {
    var h = Harness.init();
    h.setA(0xFF);
    h.load(&.{0x07});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x07 RLCA: H flag always cleared" {
    var h = Harness.init();
    h.setA(0xFF);
    h.load(&.{0x07});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x07 RLCA: all bits rotate correctly (0b11001010 -> 0b10010101)" {
    var h = Harness.init();
    h.setA(0b11001010);
    h.load(&.{0x07});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0b10010101), h.regA());
}

test "0x07 RLCA: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x07});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x08  LD (u16), SP
// ---------------------------------------------------------------------------

test "0x08 LD (u16),SP: writes SP low byte at address, high byte at address+1" {
    var h = Harness.init();
    h.setSP(0xABCD);
    // Store to work RAM at 0xC100
    h.load(&.{ 0x08, 0x00, 0xC1 }); // little-endian address 0xC100
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xCD), h.readMem(0xC100)); // low byte
    try std.testing.expectEqual(@as(u8, 0xAB), h.readMem(0xC101)); // high byte
}

test "0x08 LD (u16),SP: consumes 20 T-cycles" {
    var h = Harness.init();
    h.setSP(0x1234);
    h.load(&.{ 0x08, 0x00, 0xC1 });
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 20), cycles);
}

test "0x08 LD (u16),SP: does not affect flags" {
    var h = Harness.init();
    h.setSP(0xFFFF);
    h.load(&.{ 0x08, 0x00, 0xC1 });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x08 LD (u16),SP: does not modify SP" {
    var h = Harness.init();
    h.setSP(0x1234);
    h.load(&.{ 0x08, 0x00, 0xC1 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x1234), h.regSP());
}

// ---------------------------------------------------------------------------
// 0x09  ADD HL, BC
// ---------------------------------------------------------------------------

test "0x09 ADD HL,BC: adds BC to HL" {
    var h = Harness.init();
    h.setHL(0x0100);
    h.setBC(0x0200);
    h.load(&.{0x09});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0300), h.regHL());
}

test "0x09 ADD HL,BC: clears N flag" {
    var h = Harness.init();
    h.setHL(0x0001);
    h.setBC(0x0001);
    h.load(&.{0x09});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x09 ADD HL,BC: sets C on overflow past 0xFFFF" {
    var h = Harness.init();
    h.setHL(0xFFFF);
    h.setBC(0x0001);
    h.load(&.{0x09});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x09 ADD HL,BC: clears C when no overflow" {
    var h = Harness.init();
    h.setHL(0x0001);
    h.setBC(0x0001);
    h.load(&.{0x09});
    _ = try h.step();
    try std.testing.expect(!h.flagC());
}

test "0x09 ADD HL,BC: sets H on carry from bit 11" {
    var h = Harness.init();
    h.setHL(0x0FFF);
    h.setBC(0x0001);
    h.load(&.{0x09});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x09 ADD HL,BC: clears H when no carry from bit 11" {
    var h = Harness.init();
    h.setHL(0x0100);
    h.setBC(0x0100);
    h.load(&.{0x09});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x09 ADD HL,BC: does not affect Z flag" {
    var h = Harness.init();
    // Force Z set
    h.cpu.registers.af.parts.f |= (1 << 7);
    h.setHL(0xFFFF);
    h.setBC(0x0001); // result 0x0000 — but Z must not be touched
    h.load(&.{0x09});
    _ = try h.step();
    try std.testing.expect(h.flagZ()); // Z unchanged
}

test "0x09 ADD HL,BC: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x09});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x0A  LD A, (BC)
// ---------------------------------------------------------------------------

test "0x0A LD A,(BC): loads byte from address in BC into A" {
    var h = Harness.init();
    h.setBC(0xC000);
    h.writeMem(0xC000, 0x77);
    h.load(&.{0x0A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.regA());
}

test "0x0A LD A,(BC): consumes 8 T-cycles" {
    var h = Harness.init();
    h.setBC(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x0A});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

test "0x0A LD A,(BC): does not affect flags" {
    var h = Harness.init();
    h.setBC(0xC000);
    h.writeMem(0xC000, 0xFF);
    h.load(&.{0x0A});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x0A LD A,(BC): does not modify BC" {
    var h = Harness.init();
    h.setBC(0xC000);
    h.writeMem(0xC000, 0x01);
    h.load(&.{0x0A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xC000), h.regBC());
}

// ---------------------------------------------------------------------------
// 0x0B  DEC BC
// ---------------------------------------------------------------------------

test "0x0B DEC BC: decrements BC by 1" {
    var h = Harness.init();
    h.setBC(0x0010);
    h.load(&.{0x0B});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x000F), h.regBC());
}

test "0x0B DEC BC: wraps from 0x0000 to 0xFFFF" {
    var h = Harness.init();
    h.setBC(0x0000);
    h.load(&.{0x0B});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), h.regBC());
}

test "0x0B DEC BC: does not affect flags" {
    var h = Harness.init();
    h.setBC(0x0000);
    h.load(&.{0x0B});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x0B DEC BC: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x0B});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x0C  INC C  (same flag rules as INC B)
// ---------------------------------------------------------------------------

test "0x0C INC C: increments C by 1" {
    var h = Harness.init();
    h.setC(0x10);
    h.load(&.{0x0C});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regC());
}

test "0x0C INC C: sets Z when result wraps to 0x00" {
    var h = Harness.init();
    h.setC(0xFF);
    h.load(&.{0x0C});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x0C INC C: sets H on lower nibble wrap (0x0F -> 0x10)" {
    var h = Harness.init();
    h.setC(0x0F);
    h.load(&.{0x0C});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x0C INC C: clears N flag" {
    var h = Harness.init();
    h.setC(0x01);
    h.load(&.{0x0C});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

// ---------------------------------------------------------------------------
// 0x0D  DEC C  (same flag rules as DEC B)
// ---------------------------------------------------------------------------

test "0x0D DEC C: decrements C by 1" {
    var h = Harness.init();
    h.setC(0x10);
    h.load(&.{0x0D});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x0F), h.regC());
}

test "0x0D DEC C: sets Z when result is 0x00" {
    var h = Harness.init();
    h.setC(0x01);
    h.load(&.{0x0D});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x0D DEC C: sets N flag" {
    var h = Harness.init();
    h.setC(0x05);
    h.load(&.{0x0D});
    _ = try h.step();
    try std.testing.expect(h.flagN());
}

test "0x0D DEC C: sets H on borrow from upper nibble (0x10 -> 0x0F)" {
    var h = Harness.init();
    h.setC(0x10);
    h.load(&.{0x0D});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

// ---------------------------------------------------------------------------
// 0x0E  LD C, u8
// ---------------------------------------------------------------------------

test "0x0E LD C,u8: loads immediate byte into C" {
    var h = Harness.init();
    h.load(&.{ 0x0E, 0xAB });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regC());
}

test "0x0E LD C,u8: does not affect flags" {
    var h = Harness.init();
    h.load(&.{ 0x0E, 0xFF });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x0E LD C,u8: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{ 0x0E, 0x00 });
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x0F  RRCA
// ---------------------------------------------------------------------------

test "0x0F RRCA: bit 0 wraps into bit 7" {
    var h = Harness.init();
    h.setA(0b00000001); // only bit 0 set
    h.load(&.{0x0F});
    _ = try h.step();
    // after rotate right: bit 0 goes to bit 7 -> 0b10000000
    try std.testing.expectEqual(@as(u8, 0b10000000), h.regA());
}

test "0x0F RRCA: bit 0 is copied into C flag" {
    var h = Harness.init();
    h.setA(0b00000001);
    h.load(&.{0x0F});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x0F RRCA: C flag cleared when bit 0 was 0" {
    var h = Harness.init();
    h.setA(0b10000000);
    h.load(&.{0x0F});
    _ = try h.step();
    try std.testing.expect(!h.flagC());
}

test "0x0F RRCA: Z flag always cleared" {
    var h = Harness.init();
    h.setA(0x00);
    h.load(&.{0x0F});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x0F RRCA: N flag always cleared" {
    var h = Harness.init();
    h.setA(0xFF);
    h.load(&.{0x0F});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x0F RRCA: H flag always cleared" {
    var h = Harness.init();
    h.setA(0xFF);
    h.load(&.{0x0F});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x0F RRCA: all bits rotate correctly (0b11001010 -> 0b01100101)" {
    var h = Harness.init();
    h.setA(0b11001010);
    h.load(&.{0x0F});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0b01100101), h.regA());
}

test "0x0F RRCA: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x0F});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// Harness extensions needed for 0x10-0x1F tests
// Add these methods to the Harness struct in your actual file
//
//   pub fn setD(self: *Harness, v: u8) void { self.cpu.registers.de.parts.d = v; }
//   pub fn setE(self: *Harness, v: u8) void { self.cpu.registers.de.parts.e = v; }
//   pub fn setCarry(self: *Harness, v: bool) void {
//       if (v) {
//           self.cpu.registers.af.parts.f |= (1 << 4);
//       } else {
//           self.cpu.registers.af.parts.f &= ~@as(u8, (1 << 4));
//       }
//   }
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// 0x10  STOP
// ---------------------------------------------------------------------------

test "0x10 STOP: returns NotYetSupportedOpcode error" {
    var h = Harness.init();
    h.load(&.{ 0x10, 0x00 });
    const result = h.step();
    try std.testing.expectError(error.NotYetSupportedOpcode, result);
}

test "0x10 STOP: advances PC past both bytes before erroring" {
    var h = Harness.init();
    h.load(&.{ 0x10, 0x00 });
    const pc_before = h.regPC();
    _ = h.step() catch {};
    try std.testing.expectEqual(pc_before + 2, h.regPC());
}

// ---------------------------------------------------------------------------
// 0x11  LD DE, u16
// ---------------------------------------------------------------------------

test "0x11 LD DE,u16: loads immediate little-endian u16 into DE" {
    var h = Harness.init();
    h.load(&.{ 0x11, 0x34, 0x12 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x1234), h.regDE());
}

test "0x11 LD DE,u16: low byte goes into E, high byte into D" {
    var h = Harness.init();
    h.load(&.{ 0x11, 0xAB, 0xCD });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regE());
    try std.testing.expectEqual(@as(u8, 0xCD), h.regD());
}

test "0x11 LD DE,u16: consumes 12 T-cycles and advances PC by 3" {
    var h = Harness.init();
    h.load(&.{ 0x11, 0x00, 0x00 });
    const pc_before = h.regPC();
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 12), cycles);
    try std.testing.expectEqual(pc_before + 3, h.regPC());
}

test "0x11 LD DE,u16: does not affect flags" {
    var h = Harness.init();
    h.load(&.{ 0x11, 0xFF, 0xFF });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x11 LD DE,u16: edge case 0x0000" {
    var h = Harness.init();
    h.load(&.{ 0x11, 0x00, 0x00 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0000), h.regDE());
}

test "0x11 LD DE,u16: edge case 0xFFFF" {
    var h = Harness.init();
    h.load(&.{ 0x11, 0xFF, 0xFF });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), h.regDE());
}

// ---------------------------------------------------------------------------
// 0x12  LD (DE), A
// ---------------------------------------------------------------------------

test "0x12 LD (DE),A: writes A to memory address in DE" {
    var h = Harness.init();
    h.setDE(0xC000);
    h.setA(0x42);
    h.load(&.{0x12});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x42), h.readMem(0xC000));
}

test "0x12 LD (DE),A: consumes 8 T-cycles" {
    var h = Harness.init();
    h.setDE(0xC000);
    h.setA(0x01);
    h.load(&.{0x12});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

test "0x12 LD (DE),A: does not affect flags" {
    var h = Harness.init();
    h.setDE(0xC000);
    h.setA(0xFF);
    h.load(&.{0x12});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x12 LD (DE),A: does not modify DE" {
    var h = Harness.init();
    h.setDE(0xC000);
    h.setA(0x01);
    h.load(&.{0x12});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xC000), h.regDE());
}

// ---------------------------------------------------------------------------
// 0x13  INC DE
// ---------------------------------------------------------------------------

test "0x13 INC DE: increments DE by 1" {
    var h = Harness.init();
    h.setDE(0x0000);
    h.load(&.{0x13});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0001), h.regDE());
}

test "0x13 INC DE: wraps from 0xFFFF to 0x0000" {
    var h = Harness.init();
    h.setDE(0xFFFF);
    h.load(&.{0x13});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0000), h.regDE());
}

test "0x13 INC DE: does not affect flags" {
    var h = Harness.init();
    h.setDE(0xFFFF);
    h.load(&.{0x13});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x13 INC DE: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x13});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x14  INC D
// ---------------------------------------------------------------------------

test "0x14 INC D: increments D by 1" {
    var h = Harness.init();
    h.setD(0x00);
    h.load(&.{0x14});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x01), h.regD());
}

test "0x14 INC D: sets Z when result wraps to 0x00" {
    var h = Harness.init();
    h.setD(0xFF);
    h.load(&.{0x14});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x14 INC D: clears Z when result is non-zero" {
    var h = Harness.init();
    h.setD(0x00);
    h.load(&.{0x14});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x14 INC D: clears N flag" {
    var h = Harness.init();
    h.setD(0x10);
    h.load(&.{0x14});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x14 INC D: sets H when lower nibble wraps (0x0F -> 0x10)" {
    var h = Harness.init();
    h.setD(0x0F);
    h.load(&.{0x14});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x14 INC D: clears H when lower nibble does not wrap" {
    var h = Harness.init();
    h.setD(0x00);
    h.load(&.{0x14});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x14 INC D: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4);
    h.setD(0xFF);
    h.load(&.{0x14});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x14 INC D: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x14});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x15  DEC D
// ---------------------------------------------------------------------------

test "0x15 DEC D: decrements D by 1" {
    var h = Harness.init();
    h.setD(0x10);
    h.load(&.{0x15});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x0F), h.regD());
}

test "0x15 DEC D: wraps from 0x00 to 0xFF" {
    var h = Harness.init();
    h.setD(0x00);
    h.load(&.{0x15});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xFF), h.regD());
}

test "0x15 DEC D: sets Z when result is 0x00" {
    var h = Harness.init();
    h.setD(0x01);
    h.load(&.{0x15});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x15 DEC D: sets N flag" {
    var h = Harness.init();
    h.setD(0x10);
    h.load(&.{0x15});
    _ = try h.step();
    try std.testing.expect(h.flagN());
}

test "0x15 DEC D: sets H when lower nibble borrows (0x10 -> 0x0F)" {
    var h = Harness.init();
    h.setD(0x10);
    h.load(&.{0x15});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x15 DEC D: clears H when no borrow" {
    var h = Harness.init();
    h.setD(0x0F);
    h.load(&.{0x15});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x15 DEC D: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4);
    h.setD(0x00);
    h.load(&.{0x15});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x15 DEC D: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x15});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x16  LD D, u8
// ---------------------------------------------------------------------------

test "0x16 LD D,u8: loads immediate byte into D" {
    var h = Harness.init();
    h.load(&.{ 0x16, 0xBE });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xBE), h.regD());
}

test "0x16 LD D,u8: edge case 0x00" {
    var h = Harness.init();
    h.load(&.{ 0x16, 0x00 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x00), h.regD());
}

test "0x16 LD D,u8: edge case 0xFF" {
    var h = Harness.init();
    h.load(&.{ 0x16, 0xFF });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xFF), h.regD());
}

test "0x16 LD D,u8: consumes 8 T-cycles and advances PC by 2" {
    var h = Harness.init();
    h.load(&.{ 0x16, 0x00 });
    const pc_before = h.regPC();
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
    try std.testing.expectEqual(pc_before + 2, h.regPC());
}

test "0x16 LD D,u8: does not affect flags" {
    var h = Harness.init();
    h.load(&.{ 0x16, 0xFF });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x17  RLA
// ---------------------------------------------------------------------------

test "0x17 RLA: old carry goes into bit 0" {
    var h = Harness.init();
    h.setA(0b00000000);
    h.cpu.registers.af.parts.f |= (1 << 4); // set carry
    h.load(&.{0x17});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0b00000001), h.regA());
}

test "0x17 RLA: bit 7 goes into carry flag" {
    var h = Harness.init();
    h.setA(0b10000000);
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 4)); // clear carry
    h.load(&.{0x17});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x17 RLA: bit 7 zero clears carry" {
    var h = Harness.init();
    h.setA(0b00000000);
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 4));
    h.load(&.{0x17});
    _ = try h.step();
    try std.testing.expect(!h.flagC());
}

test "0x17 RLA: Z flag always cleared" {
    var h = Harness.init();
    h.setA(0x00);
    h.cpu.registers.af.parts.f |= (1 << 7); // force Z set
    h.load(&.{0x17});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x17 RLA: N flag always cleared" {
    var h = Harness.init();
    h.setA(0xFF);
    h.load(&.{0x17});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x17 RLA: H flag always cleared" {
    var h = Harness.init();
    h.setA(0xFF);
    h.load(&.{0x17});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x17 RLA: full rotation with carry in and out" {
    var h = Harness.init();
    // A = 0b10110101, carry = 1
    // result = 0b01101011, carry = 1 (old bit 7)
    h.setA(0b10110101);
    h.cpu.registers.af.parts.f |= (1 << 4);
    h.load(&.{0x17});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0b01101011), h.regA());
    try std.testing.expect(h.flagC());
}

test "0x17 RLA: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x17});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x18  JR i8
// ---------------------------------------------------------------------------

test "0x18 JR i8: jumps forward by positive offset" {
    var h = Harness.init();
    // PC starts at 0x0100, fetch opcode -> 0x0101, fetch offset -> 0x0102
    // offset = +5 -> PC = 0x0102 + 5 = 0x0107
    h.load(&.{ 0x18, 0x05 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0107), h.regPC());
}

test "0x18 JR i8: jumps backward by negative offset" {
    var h = Harness.init();
    // offset = -4 (0xFC as i8) -> PC = 0x0102 + (-4) = 0x00FE
    h.load(&.{ 0x18, 0xFC });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x00FE), h.regPC());
}

test "0x18 JR i8: offset of zero stays at PC+2" {
    var h = Harness.init();
    h.load(&.{ 0x18, 0x00 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0102), h.regPC());
}

test "0x18 JR i8: consumes 12 T-cycles" {
    var h = Harness.init();
    h.load(&.{ 0x18, 0x00 });
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 12), cycles);
}

test "0x18 JR i8: does not affect flags" {
    var h = Harness.init();
    h.load(&.{ 0x18, 0x00 });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x19  ADD HL, DE
// ---------------------------------------------------------------------------

test "0x19 ADD HL,DE: adds DE to HL" {
    var h = Harness.init();
    h.setHL(0x0100);
    h.setDE(0x0200);
    h.load(&.{0x19});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0300), h.regHL());
}

test "0x19 ADD HL,DE: clears N flag" {
    var h = Harness.init();
    h.setHL(0x0001);
    h.setDE(0x0001);
    h.load(&.{0x19});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x19 ADD HL,DE: sets C on overflow past 0xFFFF" {
    var h = Harness.init();
    h.setHL(0xFFFF);
    h.setDE(0x0001);
    h.load(&.{0x19});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x19 ADD HL,DE: clears C when no overflow" {
    var h = Harness.init();
    h.setHL(0x0001);
    h.setDE(0x0001);
    h.load(&.{0x19});
    _ = try h.step();
    try std.testing.expect(!h.flagC());
}

test "0x19 ADD HL,DE: sets H on carry from bit 11" {
    var h = Harness.init();
    h.setHL(0x0FFF);
    h.setDE(0x0001);
    h.load(&.{0x19});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x19 ADD HL,DE: does not affect Z flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7);
    h.setHL(0xFFFF);
    h.setDE(0x0001);
    h.load(&.{0x19});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x19 ADD HL,DE: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x19});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x1A  LD A, (DE)
// ---------------------------------------------------------------------------

test "0x1A LD A,(DE): loads byte from address in DE into A" {
    var h = Harness.init();
    h.setDE(0xC000);
    h.writeMem(0xC000, 0x55);
    h.load(&.{0x1A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x55), h.regA());
}

test "0x1A LD A,(DE): consumes 8 T-cycles" {
    var h = Harness.init();
    h.setDE(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x1A});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

test "0x1A LD A,(DE): does not affect flags" {
    var h = Harness.init();
    h.setDE(0xC000);
    h.writeMem(0xC000, 0xFF);
    h.load(&.{0x1A});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x1A LD A,(DE): does not modify DE" {
    var h = Harness.init();
    h.setDE(0xC000);
    h.writeMem(0xC000, 0x01);
    h.load(&.{0x1A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xC000), h.regDE());
}

// ---------------------------------------------------------------------------
// 0x1B  DEC DE
// ---------------------------------------------------------------------------

test "0x1B DEC DE: decrements DE by 1" {
    var h = Harness.init();
    h.setDE(0x0010);
    h.load(&.{0x1B});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x000F), h.regDE());
}

test "0x1B DEC DE: wraps from 0x0000 to 0xFFFF" {
    var h = Harness.init();
    h.setDE(0x0000);
    h.load(&.{0x1B});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), h.regDE());
}

test "0x1B DEC DE: does not affect flags" {
    var h = Harness.init();
    h.setDE(0x0000);
    h.load(&.{0x1B});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x1B DEC DE: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x1B});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x1C  INC E
// ---------------------------------------------------------------------------

test "0x1C INC E: increments E by 1" {
    var h = Harness.init();
    h.setE(0x10);
    h.load(&.{0x1C});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regE());
}

test "0x1C INC E: sets Z when result wraps to 0x00" {
    var h = Harness.init();
    h.setE(0xFF);
    h.load(&.{0x1C});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x1C INC E: sets H on lower nibble wrap (0x0F -> 0x10)" {
    var h = Harness.init();
    h.setE(0x0F);
    h.load(&.{0x1C});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x1C INC E: clears N flag" {
    var h = Harness.init();
    h.setE(0x01);
    h.load(&.{0x1C});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x1C INC E: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x1C});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x1D  DEC E
// ---------------------------------------------------------------------------

test "0x1D DEC E: decrements E by 1" {
    var h = Harness.init();
    h.setE(0x10);
    h.load(&.{0x1D});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x0F), h.regE());
}

test "0x1D DEC E: sets Z when result is 0x00" {
    var h = Harness.init();
    h.setE(0x01);
    h.load(&.{0x1D});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x1D DEC E: sets N flag" {
    var h = Harness.init();
    h.setE(0x05);
    h.load(&.{0x1D});
    _ = try h.step();
    try std.testing.expect(h.flagN());
}

test "0x1D DEC E: sets H on borrow (0x10 -> 0x0F)" {
    var h = Harness.init();
    h.setE(0x10);
    h.load(&.{0x1D});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x1D DEC E: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x1D});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x1E  LD E, u8
// ---------------------------------------------------------------------------

test "0x1E LD E,u8: loads immediate byte into E" {
    var h = Harness.init();
    h.load(&.{ 0x1E, 0xAB });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regE());
}

test "0x1E LD E,u8: does not affect flags" {
    var h = Harness.init();
    h.load(&.{ 0x1E, 0xFF });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x1E LD E,u8: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{ 0x1E, 0x00 });
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x1F  RRA
// ---------------------------------------------------------------------------

test "0x1F RRA: old carry goes into bit 7" {
    var h = Harness.init();
    h.setA(0b00000000);
    h.cpu.registers.af.parts.f |= (1 << 4); // set carry
    h.load(&.{0x1F});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0b10000000), h.regA());
}

test "0x1F RRA: bit 0 goes into carry flag" {
    var h = Harness.init();
    h.setA(0b00000001);
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 4)); // clear carry
    h.load(&.{0x1F});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x1F RRA: bit 0 zero clears carry" {
    var h = Harness.init();
    h.setA(0b00000000);
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 4));
    h.load(&.{0x1F});
    _ = try h.step();
    try std.testing.expect(!h.flagC());
}

test "0x1F RRA: Z flag always cleared" {
    var h = Harness.init();
    h.setA(0x00);
    h.cpu.registers.af.parts.f |= (1 << 7);
    h.load(&.{0x1F});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x1F RRA: N flag always cleared" {
    var h = Harness.init();
    h.setA(0xFF);
    h.load(&.{0x1F});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x1F RRA: H flag always cleared" {
    var h = Harness.init();
    h.setA(0xFF);
    h.load(&.{0x1F});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x1F RRA: full rotation with carry in and out" {
    var h = Harness.init();
    // A = 0b10110101, carry = 1
    // result = 0b11011010, carry = 1 (old bit 0)
    h.setA(0b10110101);
    h.cpu.registers.af.parts.f |= (1 << 4);
    h.load(&.{0x1F});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0b11011010), h.regA());
    try std.testing.expect(h.flagC());
}

test "0x1F RRA: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x1F});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}
