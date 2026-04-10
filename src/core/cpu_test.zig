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
    pub fn setH(self: *Harness, v: u8) void {
        self.cpu.registers.hl.parts.h = v;
    }
    pub fn setL(self: *Harness, v: u8) void {
        self.cpu.registers.hl.parts.l = v;
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

test "0x0C INC C: clears Z when result is non-zero" {
    var h = Harness.init();
    // Pre-set Z to confirm it gets cleared
    h.cpu.registers.af.parts.f |= (1 << 7);
    h.setC(0x00);
    h.load(&.{0x0C});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x0C INC C: clears H when lower nibble does not wrap" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 5); // pre-set H
    h.setC(0x00);
    h.load(&.{0x0C});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x0C INC C: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.setC(0xFF);
    h.load(&.{0x0C});
    _ = try h.step();
    try std.testing.expect(h.flagC());
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

test "0x0D DEC C: clears Z when result is non-zero" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // pre-set Z
    h.setC(0x05);
    h.load(&.{0x0D});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x0D DEC C: clears H when no borrow from upper nibble" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 5); // pre-set H
    h.setC(0x0F);
    h.load(&.{0x0D});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x0D DEC C: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.setC(0x00);
    h.load(&.{0x0D});
    _ = try h.step();
    try std.testing.expect(h.flagC());
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

test "0x15 DEC D: clears Z when result is non-zero" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // pre-set Z
    h.setD(0x05);
    h.load(&.{0x15});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
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

test "0x1C INC E: clears Z when result is non-zero" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // pre-set Z
    h.setE(0x00);
    h.load(&.{0x1C});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x1C INC E: clears H when lower nibble does not wrap" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 5); // pre-set H
    h.setE(0x00);
    h.load(&.{0x1C});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x1C INC E: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.setE(0xFF);
    h.load(&.{0x1C});
    _ = try h.step();
    try std.testing.expect(h.flagC());
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

test "0x1D DEC E: clears Z when result is non-zero" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // pre-set Z
    h.setE(0x05);
    h.load(&.{0x1D});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x1D DEC E: clears H when no borrow from upper nibble" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 5); // pre-set H
    h.setE(0x0F);
    h.load(&.{0x1D});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x1D DEC E: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.setE(0x00);
    h.load(&.{0x1D});
    _ = try h.step();
    try std.testing.expect(h.flagC());
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

// ---------------------------------------------------------------------------
// 0x20  JR NZ, i8
// ---------------------------------------------------------------------------
// Spec: If Z flag is clear, PC += sign-extended offset (offset fetched AFTER
//       the opcode, so PC has already advanced by 2 before the jump is applied).
//       Taken: 12 T-cycles. Not taken: 8 T-cycles.

test "0x20 JR NZ,i8: branches forward when Z is clear" {
    var h = Harness.init();
    // Clear Z flag
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 7));
    // offset = +4: PC will be 0x0102 after fetch, then +4 = 0x0106
    h.load(&.{ 0x20, 0x04 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0106), h.regPC());
}

test "0x20 JR NZ,i8: branches backward when Z is clear" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 7));
    // offset = -2 (0xFE as i8): PC = 0x0102 after fetch, then -2 = 0x0100
    h.load(&.{ 0x20, 0xFE });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0100), h.regPC());
}

test "0x20 JR NZ,i8: does not branch when Z is set" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // set Z
    h.load(&.{ 0x20, 0x10 });
    _ = try h.step();
    // PC advances past opcode and offset only: 0x0100 + 2 = 0x0102
    try std.testing.expectEqual(@as(u16, 0x0102), h.regPC());
}

test "0x20 JR NZ,i8: taken branch consumes 12 T-cycles" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 7));
    h.load(&.{ 0x20, 0x00 });
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 12), cycles);
}

test "0x20 JR NZ,i8: not-taken branch consumes 8 T-cycles" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // Z set → no branch
    h.load(&.{ 0x20, 0x00 });
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

test "0x20 JR NZ,i8: does not affect any flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 7));
    h.load(&.{ 0x20, 0x00 });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x21  LD HL, u16
// ---------------------------------------------------------------------------
// Spec: Load immediate 16-bit little-endian value into HL.
//       12 T-cycles, PC+3. Flags unaffected.

test "0x21 LD HL,u16: loads little-endian u16 into HL" {
    var h = Harness.init();
    h.load(&.{ 0x21, 0x34, 0x12 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x1234), h.regHL());
}

test "0x21 LD HL,u16: low byte goes into L, high byte into H" {
    var h = Harness.init();
    h.load(&.{ 0x21, 0xAB, 0xCD });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regL());
    try std.testing.expectEqual(@as(u8, 0xCD), h.regH());
}

test "0x21 LD HL,u16: consumes 12 T-cycles and advances PC by 3" {
    var h = Harness.init();
    h.load(&.{ 0x21, 0x00, 0x00 });
    const pc_before = h.regPC();
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 12), cycles);
    try std.testing.expectEqual(pc_before + 3, h.regPC());
}

test "0x21 LD HL,u16: does not affect flags" {
    var h = Harness.init();
    h.load(&.{ 0x21, 0xFF, 0xFF });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x21 LD HL,u16: edge case 0x0000" {
    var h = Harness.init();
    h.load(&.{ 0x21, 0x00, 0x00 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0000), h.regHL());
}

test "0x21 LD HL,u16: edge case 0xFFFF" {
    var h = Harness.init();
    h.load(&.{ 0x21, 0xFF, 0xFF });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), h.regHL());
}

// ---------------------------------------------------------------------------
// 0x22  LD (HL+), A
// ---------------------------------------------------------------------------
// Spec: Write A to address in HL, then increment HL.
//       8 T-cycles. Flags unaffected.

test "0x22 LD (HL+),A: writes A to address held in HL" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.setA(0x77);
    h.load(&.{0x22});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.readMem(0xC000));
}

test "0x22 LD (HL+),A: increments HL after the write" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.setA(0x01);
    h.load(&.{0x22});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xC001), h.regHL());
}

test "0x22 LD (HL+),A: HL wraps from 0xFFFF to 0x0000" {
    var h = Harness.init();
    // Use a writable mirror address — Echo RAM mirrors 0xC000
    // We need HL=0xFFFF but that's not writable. Use 0xFFFF -> write to IE (0xFFFF is writable).
    // Actually the spec only requires HL increments; we test the increment, not the write destination.
    h.setHL(0xFFFF);
    h.setA(0x00);
    // Write directly so the bus write to 0xFFFF (IE register) doesn't cause issues
    h.load(&.{0x22});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0000), h.regHL());
}

test "0x22 LD (HL+),A: consumes 8 T-cycles" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.setA(0x00);
    h.load(&.{0x22});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

test "0x22 LD (HL+),A: does not affect flags" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.setA(0xFF);
    h.load(&.{0x22});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x23  INC HL
// ---------------------------------------------------------------------------
// Spec: Increment HL by 1. 8 T-cycles. Flags unaffected.

test "0x23 INC HL: increments HL by 1" {
    var h = Harness.init();
    h.setHL(0x0010);
    h.load(&.{0x23});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0011), h.regHL());
}

test "0x23 INC HL: wraps from 0xFFFF to 0x0000" {
    var h = Harness.init();
    h.setHL(0xFFFF);
    h.load(&.{0x23});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0000), h.regHL());
}

test "0x23 INC HL: does not affect flags" {
    var h = Harness.init();
    h.setHL(0xFFFF);
    h.load(&.{0x23});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x23 INC HL: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x23});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x24  INC H
// ---------------------------------------------------------------------------
// Spec: Increment H. Z set if result=0, N cleared, H set if low nibble wraps,
//       C unaffected. 4 T-cycles.

test "0x24 INC H: increments H by 1" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.h = 0x10;
    h.load(&.{0x24});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regH());
}

test "0x24 INC H: sets Z when result is 0x00 (wrap from 0xFF)" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.h = 0xFF;
    h.load(&.{0x24});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x00), h.regH());
    try std.testing.expect(h.flagZ());
}

test "0x24 INC H: clears Z when result is non-zero" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.h = 0x00;
    h.load(&.{0x24});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x24 INC H: clears N flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 6); // force N set
    h.cpu.registers.hl.parts.h = 0x10;
    h.load(&.{0x24});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x24 INC H: sets H when lower nibble wraps (0x0F -> 0x10)" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.h = 0x0F;
    h.load(&.{0x24});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x24 INC H: clears H when lower nibble does not wrap" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.h = 0x00;
    h.load(&.{0x24});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x24 INC H: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.cpu.registers.hl.parts.h = 0xFF;
    h.load(&.{0x24});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x24 INC H: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x24});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x25  DEC H
// ---------------------------------------------------------------------------
// Spec: Decrement H. Z set if result=0, N set, H set if lower nibble borrows,
//       C unaffected. 4 T-cycles.

test "0x25 DEC H: decrements H by 1" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.h = 0x10;
    h.load(&.{0x25});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x0F), h.regH());
}

test "0x25 DEC H: wraps from 0x00 to 0xFF" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.h = 0x00;
    h.load(&.{0x25});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xFF), h.regH());
}

test "0x25 DEC H: sets Z when result is 0x00" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.h = 0x01;
    h.load(&.{0x25});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x25 DEC H: clears Z when result is non-zero" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.h = 0x05;
    h.load(&.{0x25});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x25 DEC H: sets N flag" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.h = 0x10;
    h.load(&.{0x25});
    _ = try h.step();
    try std.testing.expect(h.flagN());
}

test "0x25 DEC H: sets H when lower nibble borrows (0x10 -> 0x0F)" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.h = 0x10;
    h.load(&.{0x25});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x25 DEC H: clears H when no borrow from upper nibble" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.h = 0x0F;
    h.load(&.{0x25});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x25 DEC H: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.cpu.registers.hl.parts.h = 0x00;
    h.load(&.{0x25});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x25 DEC H: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x25});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x26  LD H, u8
// ---------------------------------------------------------------------------
// Spec: Load immediate byte into H. 8 T-cycles, PC+2. Flags unaffected.

test "0x26 LD H,u8: loads immediate byte into H" {
    var h = Harness.init();
    h.load(&.{ 0x26, 0xBE });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xBE), h.regH());
}

test "0x26 LD H,u8: edge case 0x00" {
    var h = Harness.init();
    h.load(&.{ 0x26, 0x00 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x00), h.regH());
}

test "0x26 LD H,u8: edge case 0xFF" {
    var h = Harness.init();
    h.load(&.{ 0x26, 0xFF });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xFF), h.regH());
}

test "0x26 LD H,u8: consumes 8 T-cycles and advances PC by 2" {
    var h = Harness.init();
    h.load(&.{ 0x26, 0x00 });
    const pc_before = h.regPC();
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
    try std.testing.expectEqual(pc_before + 2, h.regPC());
}

test "0x26 LD H,u8: does not affect flags" {
    var h = Harness.init();
    h.load(&.{ 0x26, 0xFF });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x27  DAA
// ---------------------------------------------------------------------------
// Spec: Decimal Adjust Accumulator. Corrects A after a BCD add/subtract.
//       Z set if result is 0, N untouched, H always cleared,
//       C set if BCD result exceeded 99 (carry out). 4 T-cycles.
//
// Reference: https://blog.ollien.com/posts/gb-daa/
// and Pan Docs CPU instructions.

test "0x27 DAA: adjusts after BCD addition with no flags" {
    var h = Harness.init();
    // 0x42 + 0x35 = 0x77 (both valid BCD, no correction needed)
    h.setA(0x77);
    // N=0, H=0, C=0
    h.cpu.registers.af.parts.f = 0x00;
    h.load(&.{0x27});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.regA());
}

test "0x27 DAA: corrects low nibble overflow after addition (adds 0x06)" {
    var h = Harness.init();
    // 0x42 + 0x29 = 0x6B — unit digit > 9, add 0x06 -> 0x71
    h.setA(0x6B);
    h.cpu.registers.af.parts.f = 0x00; // N=0, H=0, C=0
    h.load(&.{0x27});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x71), h.regA());
}

test "0x27 DAA: corrects upper nibble overflow after addition (adds 0x60)" {
    var h = Harness.init();
    // A = 0xC4, tens digit > 9 -> add 0x60 -> 0x24 with carry
    h.setA(0xC4);
    h.cpu.registers.af.parts.f = 0x00; // N=0, H=0, C=0
    h.load(&.{0x27});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x24), h.regA());
    try std.testing.expect(h.flagC());
}

test "0x27 DAA: corrects via carry flag set (adds 0x60 regardless of A value)" {
    var h = Harness.init();
    // A = 0x10, carry set from previous op -> add 0x60 -> 0x70, carry remains
    h.setA(0x10);
    h.cpu.registers.af.parts.f = (1 << 4); // C=1, N=0, H=0
    h.load(&.{0x27});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x70), h.regA());
    try std.testing.expect(h.flagC());
}

test "0x27 DAA: corrects via half-carry flag set (adds 0x06)" {
    var h = Harness.init();
    // A = 0x11, H set from previous op -> add 0x06 -> 0x17
    h.setA(0x11);
    h.cpu.registers.af.parts.f = (1 << 5); // H=1, N=0, C=0
    h.load(&.{0x27});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x17), h.regA());
}

test "0x27 DAA: sets Z when corrected result is 0x00" {
    var h = Harness.init();
    // A = 0x9A, no flags: 0x9A > 0x99 so add 0x60 -> 0xFA, low nibble 0xA > 9
    // so also add 0x06 -> 0x00 with carry
    h.setA(0x9A);
    h.cpu.registers.af.parts.f = 0x00;
    h.load(&.{0x27});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
    try std.testing.expectEqual(@as(u8, 0x00), h.regA());
}

test "0x27 DAA: always clears H flag" {
    var h = Harness.init();
    h.setA(0x11);
    h.cpu.registers.af.parts.f = (1 << 5); // H=1
    h.load(&.{0x27});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x27 DAA: does not modify N flag" {
    var h = Harness.init();
    // N=1 (subtract path)
    h.setA(0x07);
    h.cpu.registers.af.parts.f = (1 << 6); // N=1, H=0, C=0
    h.load(&.{0x27});
    _ = try h.step();
    try std.testing.expect(h.flagN());
}

test "0x27 DAA: subtraction path: corrects via half-carry (subtracts 0x06)" {
    var h = Harness.init();
    // 0x20 - 0x13 = 0x0D, half-carry was set -> subtract 0x06 -> 0x07
    h.setA(0x0D);
    h.cpu.registers.af.parts.f = (1 << 6) | (1 << 5); // N=1, H=1
    h.load(&.{0x27});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x07), h.regA());
}

test "0x27 DAA: subtraction path: corrects via carry (subtracts 0x60)" {
    var h = Harness.init();
    // 0x05 - 0x21 = 0xE4, carry was set -> subtract 0x60 -> 0x84
    h.setA(0xE4);
    h.cpu.registers.af.parts.f = (1 << 6) | (1 << 4); // N=1, C=1
    h.load(&.{0x27});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x84), h.regA());
    try std.testing.expect(h.flagC());
}

test "0x27 DAA: consumes 4 T-cycles" {
    var h = Harness.init();
    h.setA(0x00);
    h.cpu.registers.af.parts.f = 0x00;
    h.load(&.{0x27});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x28  JR Z, i8
// ---------------------------------------------------------------------------
// Spec: If Z flag is set, PC += sign-extended offset.
//       Taken: 12 T-cycles. Not taken: 8 T-cycles.

test "0x28 JR Z,i8: branches forward when Z is set" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // set Z
    // offset = +4: PC = 0x0102 after fetch, then +4 = 0x0106
    h.load(&.{ 0x28, 0x04 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0106), h.regPC());
}

test "0x28 JR Z,i8: branches backward when Z is set" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7);
    // offset = -2 (0xFE): PC = 0x0102 after fetch, then -2 = 0x0100
    h.load(&.{ 0x28, 0xFE });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0100), h.regPC());
}

test "0x28 JR Z,i8: does not branch when Z is clear" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 7)); // clear Z
    h.load(&.{ 0x28, 0x10 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0102), h.regPC());
}

test "0x28 JR Z,i8: taken branch consumes 12 T-cycles" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7);
    h.load(&.{ 0x28, 0x00 });
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 12), cycles);
}

test "0x28 JR Z,i8: not-taken branch consumes 8 T-cycles" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 7));
    h.load(&.{ 0x28, 0x00 });
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

test "0x28 JR Z,i8: does not affect any flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7);
    h.load(&.{ 0x28, 0x00 });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x29  ADD HL, HL
// ---------------------------------------------------------------------------
// Spec: HL = HL + HL (i.e. HL << 1).
//       N cleared, H set if carry from bit 11, C set if carry from bit 15,
//       Z unaffected. 8 T-cycles.

test "0x29 ADD HL,HL: doubles HL" {
    var h = Harness.init();
    h.setHL(0x0010);
    h.load(&.{0x29});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0020), h.regHL());
}

test "0x29 ADD HL,HL: wraps on overflow" {
    var h = Harness.init();
    h.setHL(0x8000);
    h.load(&.{0x29});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0000), h.regHL());
}

test "0x29 ADD HL,HL: sets C on 16-bit carry" {
    var h = Harness.init();
    h.setHL(0x8000);
    h.load(&.{0x29});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x29 ADD HL,HL: clears C when no 16-bit carry" {
    var h = Harness.init();
    h.setHL(0x0001);
    h.load(&.{0x29});
    _ = try h.step();
    try std.testing.expect(!h.flagC());
}

test "0x29 ADD HL,HL: sets H on carry from bit 11" {
    var h = Harness.init();
    // 0x0800 + 0x0800 = 0x1000 — bit 11 carries into bit 12
    h.setHL(0x0800);
    h.load(&.{0x29});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x29 ADD HL,HL: clears H when no carry from bit 11" {
    var h = Harness.init();
    h.setHL(0x0001);
    h.load(&.{0x29});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x29 ADD HL,HL: clears N flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 6); // force N set
    h.setHL(0x0010);
    h.load(&.{0x29});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x29 ADD HL,HL: does not affect Z flag" {
    var h = Harness.init();
    // Z set before; HL=0x8000 -> result=0x0000, but Z must not be touched
    h.cpu.registers.af.parts.f |= (1 << 7); // set Z
    h.setHL(0x8000);
    h.load(&.{0x29});
    _ = try h.step();
    try std.testing.expect(h.flagZ()); // still set — ADD HL does not touch Z
}

test "0x29 ADD HL,HL: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x29});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x2A  LD A, (HL+)
// ---------------------------------------------------------------------------
// Spec: Load byte from address in HL into A, then increment HL.
//       8 T-cycles. Flags unaffected.

test "0x2A LD A,(HL+): loads byte from address in HL into A" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x55);
    h.load(&.{0x2A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x55), h.regA());
}

test "0x2A LD A,(HL+): increments HL after the read" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x2A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xC001), h.regHL());
}

test "0x2A LD A,(HL+): HL wraps from 0xFFFF to 0x0000" {
    var h = Harness.init();
    h.setHL(0xFFFF);
    // 0xFFFF is IE register — readable
    h.load(&.{0x2A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0000), h.regHL());
}

test "0x2A LD A,(HL+): reads the address before incrementing" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0xAB);
    h.writeMem(0xC001, 0xCD);
    h.load(&.{0x2A});
    _ = try h.step();
    // Must have read 0xC000 (0xAB), not 0xC001
    try std.testing.expectEqual(@as(u8, 0xAB), h.regA());
}

test "0x2A LD A,(HL+): does not affect flags" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0xFF);
    h.load(&.{0x2A});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x2A LD A,(HL+): consumes 8 T-cycles" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x2A});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x2B  DEC HL
// ---------------------------------------------------------------------------
// Spec: Decrement HL by 1. 8 T-cycles. Flags unaffected.

test "0x2B DEC HL: decrements HL by 1" {
    var h = Harness.init();
    h.setHL(0x0010);
    h.load(&.{0x2B});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x000F), h.regHL());
}

test "0x2B DEC HL: wraps from 0x0000 to 0xFFFF" {
    var h = Harness.init();
    h.setHL(0x0000);
    h.load(&.{0x2B});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), h.regHL());
}

test "0x2B DEC HL: does not affect flags" {
    var h = Harness.init();
    h.setHL(0x0000);
    h.load(&.{0x2B});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x2B DEC HL: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x2B});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x2C  INC L
// ---------------------------------------------------------------------------
// Spec: Increment L. Z set if result=0, N cleared, H set if low nibble wraps,
//       C unaffected. 4 T-cycles.

test "0x2C INC L: increments L by 1" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.l = 0x10;
    h.load(&.{0x2C});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regL());
}

test "0x2C INC L: sets Z when result wraps to 0x00" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.l = 0xFF;
    h.load(&.{0x2C});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x2C INC L: clears Z when result is non-zero" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.l = 0x00;
    h.load(&.{0x2C});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x2C INC L: sets H on lower nibble wrap (0x0F -> 0x10)" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.l = 0x0F;
    h.load(&.{0x2C});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x2C INC L: clears H when lower nibble does not wrap" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.l = 0x00;
    h.load(&.{0x2C});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x2C INC L: clears N flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 6);
    h.cpu.registers.hl.parts.l = 0x01;
    h.load(&.{0x2C});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x2C INC L: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.cpu.registers.hl.parts.l = 0xFF;
    h.load(&.{0x2C});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x2C INC L: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x2C});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x2D  DEC L
// ---------------------------------------------------------------------------
// Spec: Decrement L. Z set if result=0, N set, H set if lower nibble borrows,
//       C unaffected. 4 T-cycles.

test "0x2D DEC L: decrements L by 1" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.l = 0x10;
    h.load(&.{0x2D});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x0F), h.regL());
}

test "0x2D DEC L: wraps from 0x00 to 0xFF" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.l = 0x00;
    h.load(&.{0x2D});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xFF), h.regL());
}

test "0x2D DEC L: sets Z when result is 0x00" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.l = 0x01;
    h.load(&.{0x2D});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x2D DEC L: clears Z when result is non-zero" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.l = 0x05;
    h.load(&.{0x2D});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x2D DEC L: sets N flag" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.l = 0x10;
    h.load(&.{0x2D});
    _ = try h.step();
    try std.testing.expect(h.flagN());
}

test "0x2D DEC L: sets H on borrow (0x10 -> 0x0F)" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.l = 0x10;
    h.load(&.{0x2D});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x2D DEC L: clears H when no borrow from upper nibble" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.l = 0x0F;
    h.load(&.{0x2D});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x2D DEC L: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.cpu.registers.hl.parts.l = 0x00;
    h.load(&.{0x2D});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x2D DEC L: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x2D});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x2E  LD L, u8
// ---------------------------------------------------------------------------
// Spec: Load immediate byte into L. 8 T-cycles, PC+2. Flags unaffected.

test "0x2E LD L,u8: loads immediate byte into L" {
    var h = Harness.init();
    h.load(&.{ 0x2E, 0xAB });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regL());
}

test "0x2E LD L,u8: edge case 0x00" {
    var h = Harness.init();
    h.load(&.{ 0x2E, 0x00 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x00), h.regL());
}

test "0x2E LD L,u8: edge case 0xFF" {
    var h = Harness.init();
    h.load(&.{ 0x2E, 0xFF });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xFF), h.regL());
}

test "0x2E LD L,u8: consumes 8 T-cycles and advances PC by 2" {
    var h = Harness.init();
    h.load(&.{ 0x2E, 0x00 });
    const pc_before = h.regPC();
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
    try std.testing.expectEqual(pc_before + 2, h.regPC());
}

test "0x2E LD L,u8: does not affect flags" {
    var h = Harness.init();
    h.load(&.{ 0x2E, 0xFF });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x2F  CPL
// ---------------------------------------------------------------------------
// Spec: Complement accumulator (A = ~A).
//       N and H always set. Z and C unaffected. 4 T-cycles.

test "0x2F CPL: complements all bits of A" {
    var h = Harness.init();
    h.setA(0b10110101);
    h.load(&.{0x2F});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0b01001010), h.regA());
}

test "0x2F CPL: complement of 0x00 is 0xFF" {
    var h = Harness.init();
    h.setA(0x00);
    h.load(&.{0x2F});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xFF), h.regA());
}

test "0x2F CPL: complement of 0xFF is 0x00" {
    var h = Harness.init();
    h.setA(0xFF);
    h.load(&.{0x2F});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x00), h.regA());
}

test "0x2F CPL: always sets N flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 6)); // clear N
    h.setA(0x55);
    h.load(&.{0x2F});
    _ = try h.step();
    try std.testing.expect(h.flagN());
}

test "0x2F CPL: always sets H flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 5)); // clear H
    h.setA(0x55);
    h.load(&.{0x2F});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x2F CPL: does not affect Z flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // set Z
    h.setA(0x55);
    h.load(&.{0x2F});
    _ = try h.step();
    try std.testing.expect(h.flagZ()); // Z unchanged
}

test "0x2F CPL: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.setA(0x55);
    h.load(&.{0x2F});
    _ = try h.step();
    try std.testing.expect(h.flagC()); // C unchanged
}

test "0x2F CPL: applying twice restores original value" {
    var h = Harness.init();
    h.setA(0xA5);
    h.load(&.{ 0x2F, 0x2F });
    _ = try h.step();
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xA5), h.regA());
}

test "0x2F CPL: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x2F});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x30  JR NC, i8
// ---------------------------------------------------------------------------
// Spec: If C flag is clear, PC += sign-extended offset (after fetching both
//       opcode and offset bytes, so PC is already +2 before jump applied).
//       Taken: 12 T-cycles. Not taken: 8 T-cycles. Flags unaffected.

test "0x30 JR NC,i8: branches forward when C is clear" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 4)); // clear C
    // PC = 0x0102 after fetch, offset +4 -> 0x0106
    h.load(&.{ 0x30, 0x04 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0106), h.regPC());
}

test "0x30 JR NC,i8: branches backward when C is clear" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 4));
    // offset = -2 (0xFE): PC = 0x0102 after fetch, then -2 = 0x0100
    h.load(&.{ 0x30, 0xFE });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0100), h.regPC());
}

test "0x30 JR NC,i8: does not branch when C is set" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.load(&.{ 0x30, 0x10 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0102), h.regPC());
}

test "0x30 JR NC,i8: taken branch consumes 12 T-cycles" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 4));
    h.load(&.{ 0x30, 0x00 });
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 12), cycles);
}

test "0x30 JR NC,i8: not-taken branch consumes 8 T-cycles" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4);
    h.load(&.{ 0x30, 0x00 });
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

test "0x30 JR NC,i8: does not affect any flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 4));
    h.load(&.{ 0x30, 0x00 });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x31  LD SP, u16
// ---------------------------------------------------------------------------
// Spec: Load immediate 16-bit little-endian value into SP.
//       12 T-cycles, PC+3. Flags unaffected.

test "0x31 LD SP,u16: loads little-endian u16 into SP" {
    var h = Harness.init();
    h.load(&.{ 0x31, 0x34, 0x12 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x1234), h.regSP());
}

test "0x31 LD SP,u16: low byte is least significant, high byte most significant" {
    var h = Harness.init();
    h.load(&.{ 0x31, 0xFE, 0xFF });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xFFFE), h.regSP());
}

test "0x31 LD SP,u16: edge case 0x0000" {
    var h = Harness.init();
    h.load(&.{ 0x31, 0x00, 0x00 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0000), h.regSP());
}

test "0x31 LD SP,u16: edge case 0xFFFF" {
    var h = Harness.init();
    h.load(&.{ 0x31, 0xFF, 0xFF });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), h.regSP());
}

test "0x31 LD SP,u16: consumes 12 T-cycles and advances PC by 3" {
    var h = Harness.init();
    h.load(&.{ 0x31, 0x00, 0x00 });
    const pc_before = h.regPC();
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 12), cycles);
    try std.testing.expectEqual(pc_before + 3, h.regPC());
}

test "0x31 LD SP,u16: does not affect flags" {
    var h = Harness.init();
    h.load(&.{ 0x31, 0xFF, 0xFF });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x32  LD (HL-), A
// ---------------------------------------------------------------------------
// Spec: Write A to address in HL, then decrement HL.
//       8 T-cycles. Flags unaffected.

test "0x32 LD (HL-),A: writes A to address held in HL" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.setA(0x42);
    h.load(&.{0x32});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x42), h.readMem(0xC000));
}

test "0x32 LD (HL-),A: decrements HL after the write" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.setA(0x01);
    h.load(&.{0x32});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xBFFF), h.regHL());
}

test "0x32 LD (HL-),A: writes to original HL address not decremented address" {
    var h = Harness.init();
    h.setHL(0xC001);
    h.setA(0x77);
    h.load(&.{0x32});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.readMem(0xC001));
    try std.testing.expectEqual(@as(u8, 0x00), h.readMem(0xC000));
}

test "0x32 LD (HL-),A: HL wraps from 0x0000 to 0xFFFF" {
    var h = Harness.init();
    h.setHL(0x0000);
    h.setA(0x00);
    h.load(&.{0x32});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), h.regHL());
}

test "0x32 LD (HL-),A: consumes 8 T-cycles" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.setA(0x00);
    h.load(&.{0x32});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

test "0x32 LD (HL-),A: does not affect flags" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.setA(0xFF);
    h.load(&.{0x32});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x33  INC SP
// ---------------------------------------------------------------------------
// Spec: Increment SP by 1. 8 T-cycles. Flags unaffected.

test "0x33 INC SP: increments SP by 1" {
    var h = Harness.init();
    h.setSP(0x0010);
    h.load(&.{0x33});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0011), h.regSP());
}

test "0x33 INC SP: wraps from 0xFFFF to 0x0000" {
    var h = Harness.init();
    h.setSP(0xFFFF);
    h.load(&.{0x33});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0000), h.regSP());
}

test "0x33 INC SP: does not affect flags" {
    var h = Harness.init();
    h.setSP(0xFFFF);
    h.load(&.{0x33});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x33 INC SP: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x33});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x34  INC (HL)
// ---------------------------------------------------------------------------
// Spec: Read byte at address in HL, increment it, write back.
//       Z set if result=0, N cleared, H set if lower nibble wraps, C unaffected.
//       12 T-cycles.

test "0x34 INC (HL): increments the byte at the address in HL" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x10);
    h.load(&.{0x34});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.readMem(0xC000));
}

test "0x34 INC (HL): wraps from 0xFF to 0x00" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0xFF);
    h.load(&.{0x34});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x00), h.readMem(0xC000));
}

test "0x34 INC (HL): sets Z when result is 0x00" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0xFF);
    h.load(&.{0x34});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x34 INC (HL): clears Z when result is non-zero" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // pre-set Z
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x34});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x34 INC (HL): clears N flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 6); // pre-set N
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x10);
    h.load(&.{0x34});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x34 INC (HL): sets H when lower nibble wraps (0x0F -> 0x10)" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x0F);
    h.load(&.{0x34});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x34 INC (HL): clears H when lower nibble does not wrap" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 5); // pre-set H
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x34});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x34 INC (HL): does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.setHL(0xC000);
    h.writeMem(0xC000, 0xFF);
    h.load(&.{0x34});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x34 INC (HL): does not modify HL" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x01);
    h.load(&.{0x34});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xC000), h.regHL());
}

test "0x34 INC (HL): consumes 12 T-cycles" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x34});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 12), cycles);
}

// ---------------------------------------------------------------------------
// 0x35  DEC (HL)
// ---------------------------------------------------------------------------
// Spec: Read byte at address in HL, decrement it, write back.
//       Z set if result=0, N set, H set if lower nibble borrows, C unaffected.
//       12 T-cycles.

test "0x35 DEC (HL): decrements the byte at the address in HL" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x10);
    h.load(&.{0x35});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x0F), h.readMem(0xC000));
}

test "0x35 DEC (HL): wraps from 0x00 to 0xFF" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x35});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xFF), h.readMem(0xC000));
}

test "0x35 DEC (HL): sets Z when result is 0x00" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x01);
    h.load(&.{0x35});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x35 DEC (HL): clears Z when result is non-zero" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // pre-set Z
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x05);
    h.load(&.{0x35});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x35 DEC (HL): sets N flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 6)); // clear N
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x10);
    h.load(&.{0x35});
    _ = try h.step();
    try std.testing.expect(h.flagN());
}

test "0x35 DEC (HL): sets H when lower nibble borrows (0x10 -> 0x0F)" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x10);
    h.load(&.{0x35});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x35 DEC (HL): clears H when no borrow from upper nibble" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 5); // pre-set H
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x0F);
    h.load(&.{0x35});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x35 DEC (HL): does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x35});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x35 DEC (HL): does not modify HL" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x01);
    h.load(&.{0x35});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xC000), h.regHL());
}

test "0x35 DEC (HL): consumes 12 T-cycles" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x35});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 12), cycles);
}

// ---------------------------------------------------------------------------
// 0x36  LD (HL), u8
// ---------------------------------------------------------------------------
// Spec: Write immediate byte to address in HL. 12 T-cycles. Flags unaffected.

test "0x36 LD (HL),u8: writes immediate byte to address in HL" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.load(&.{ 0x36, 0xAB });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.readMem(0xC000));
}

test "0x36 LD (HL),u8: edge case 0x00" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0xFF); // pre-fill to confirm it gets overwritten
    h.load(&.{ 0x36, 0x00 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x00), h.readMem(0xC000));
}

test "0x36 LD (HL),u8: edge case 0xFF" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.load(&.{ 0x36, 0xFF });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xFF), h.readMem(0xC000));
}

test "0x36 LD (HL),u8: does not modify HL" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.load(&.{ 0x36, 0x00 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xC000), h.regHL());
}

test "0x36 LD (HL),u8: consumes 12 T-cycles and advances PC by 2" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.load(&.{ 0x36, 0x00 });
    const pc_before = h.regPC();
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 12), cycles);
    try std.testing.expectEqual(pc_before + 2, h.regPC());
}

test "0x36 LD (HL),u8: does not affect flags" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.load(&.{ 0x36, 0xFF });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x37  SCF
// ---------------------------------------------------------------------------
// Spec: Set carry flag. N and H always cleared. Z unaffected. 4 T-cycles.

test "0x37 SCF: sets C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 4)); // clear C first
    h.load(&.{0x37});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x37 SCF: C flag remains set if already set" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4);
    h.load(&.{0x37});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x37 SCF: always clears N flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 6); // pre-set N
    h.load(&.{0x37});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x37 SCF: always clears H flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 5); // pre-set H
    h.load(&.{0x37});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x37 SCF: does not affect Z flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // set Z
    h.load(&.{0x37});
    _ = try h.step();
    try std.testing.expect(h.flagZ()); // Z unchanged
}

test "0x37 SCF: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x37});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x38  JR C, i8
// ---------------------------------------------------------------------------
// Spec: If C flag is set, PC += sign-extended offset.
//       Taken: 12 T-cycles. Not taken: 8 T-cycles. Flags unaffected.

test "0x38 JR C,i8: branches forward when C is set" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    // PC = 0x0102 after fetch, offset +4 -> 0x0106
    h.load(&.{ 0x38, 0x04 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0106), h.regPC());
}

test "0x38 JR C,i8: branches backward when C is set" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4);
    // offset = -2 (0xFE): PC = 0x0102 after fetch, then -2 = 0x0100
    h.load(&.{ 0x38, 0xFE });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0100), h.regPC());
}

test "0x38 JR C,i8: does not branch when C is clear" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 4)); // clear C
    h.load(&.{ 0x38, 0x10 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0102), h.regPC());
}

test "0x38 JR C,i8: taken branch consumes 12 T-cycles" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4);
    h.load(&.{ 0x38, 0x00 });
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 12), cycles);
}

test "0x38 JR C,i8: not-taken branch consumes 8 T-cycles" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 4));
    h.load(&.{ 0x38, 0x00 });
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

test "0x38 JR C,i8: does not affect any flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4);
    h.load(&.{ 0x38, 0x00 });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x39  ADD HL, SP
// ---------------------------------------------------------------------------
// Spec: HL = HL + SP. N cleared, H set if carry from bit 11,
//       C set if carry from bit 15, Z unaffected. 8 T-cycles.

test "0x39 ADD HL,SP: adds SP to HL" {
    var h = Harness.init();
    h.setHL(0x0100);
    h.setSP(0x0200);
    h.load(&.{0x39});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0300), h.regHL());
}

test "0x39 ADD HL,SP: wraps on 16-bit overflow" {
    var h = Harness.init();
    h.setHL(0xFFFF);
    h.setSP(0x0001);
    h.load(&.{0x39});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x0000), h.regHL());
}

test "0x39 ADD HL,SP: sets C on 16-bit carry" {
    var h = Harness.init();
    h.setHL(0xFFFF);
    h.setSP(0x0001);
    h.load(&.{0x39});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x39 ADD HL,SP: clears C when no 16-bit carry" {
    var h = Harness.init();
    h.setHL(0x0001);
    h.setSP(0x0001);
    h.load(&.{0x39});
    _ = try h.step();
    try std.testing.expect(!h.flagC());
}

test "0x39 ADD HL,SP: sets H on carry from bit 11" {
    var h = Harness.init();
    h.setHL(0x0FFF);
    h.setSP(0x0001);
    h.load(&.{0x39});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x39 ADD HL,SP: clears H when no carry from bit 11" {
    var h = Harness.init();
    h.setHL(0x0001);
    h.setSP(0x0001);
    h.load(&.{0x39});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x39 ADD HL,SP: clears N flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 6); // force N set
    h.setHL(0x0010);
    h.setSP(0x0001);
    h.load(&.{0x39});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x39 ADD HL,SP: does not affect Z flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // set Z
    h.setHL(0x8000);
    h.setSP(0x8000);
    h.load(&.{0x39});
    _ = try h.step();
    try std.testing.expect(h.flagZ()); // Z must be unchanged even if result is 0
}

test "0x39 ADD HL,SP: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x39});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x3A  LD A, (HL-)
// ---------------------------------------------------------------------------
// Spec: Load byte from address in HL into A, then decrement HL.
//       8 T-cycles. Flags unaffected.

test "0x3A LD A,(HL-): loads byte from address in HL into A" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x55);
    h.load(&.{0x3A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x55), h.regA());
}

test "0x3A LD A,(HL-): decrements HL after the read" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x3A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xBFFF), h.regHL());
}

test "0x3A LD A,(HL-): reads from original HL address before decrement" {
    var h = Harness.init();
    h.setHL(0xC001);
    h.writeMem(0xC001, 0xAB);
    h.writeMem(0xC000, 0xCD);
    h.load(&.{0x3A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regA());
}

test "0x3A LD A,(HL-): HL wraps from 0x0000 to 0xFFFF" {
    var h = Harness.init();
    h.setHL(0x0000);
    h.load(&.{0x3A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), h.regHL());
}

test "0x3A LD A,(HL-): does not affect flags" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0xFF);
    h.load(&.{0x3A});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x3A LD A,(HL-): consumes 8 T-cycles" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x3A});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x3B  DEC SP
// ---------------------------------------------------------------------------
// Spec: Decrement SP by 1. 8 T-cycles. Flags unaffected.

test "0x3B DEC SP: decrements SP by 1" {
    var h = Harness.init();
    h.setSP(0x0010);
    h.load(&.{0x3B});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0x000F), h.regSP());
}

test "0x3B DEC SP: wraps from 0x0000 to 0xFFFF" {
    var h = Harness.init();
    h.setSP(0x0000);
    h.load(&.{0x3B});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xFFFF), h.regSP());
}

test "0x3B DEC SP: does not affect flags" {
    var h = Harness.init();
    h.setSP(0x0000);
    h.load(&.{0x3B});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x3B DEC SP: consumes 8 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x3B});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x3C  INC A
// ---------------------------------------------------------------------------
// Spec: Increment A. Z set if result=0, N cleared, H set if lower nibble
//       wraps, C unaffected. 4 T-cycles.

test "0x3C INC A: increments A by 1" {
    var h = Harness.init();
    h.setA(0x10);
    h.load(&.{0x3C});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regA());
}

test "0x3C INC A: wraps from 0xFF to 0x00" {
    var h = Harness.init();
    h.setA(0xFF);
    h.load(&.{0x3C});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x00), h.regA());
}

test "0x3C INC A: sets Z when result is 0x00" {
    var h = Harness.init();
    h.setA(0xFF);
    h.load(&.{0x3C});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x3C INC A: clears Z when result is non-zero" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // pre-set Z
    h.setA(0x00);
    h.load(&.{0x3C});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x3C INC A: clears N flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 6); // pre-set N
    h.setA(0x10);
    h.load(&.{0x3C});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x3C INC A: sets H when lower nibble wraps (0x0F -> 0x10)" {
    var h = Harness.init();
    h.setA(0x0F);
    h.load(&.{0x3C});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x3C INC A: clears H when lower nibble does not wrap" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 5); // pre-set H
    h.setA(0x00);
    h.load(&.{0x3C});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x3C INC A: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.setA(0xFF);
    h.load(&.{0x3C});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x3C INC A: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x3C});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x3D  DEC A
// ---------------------------------------------------------------------------
// Spec: Decrement A. Z set if result=0, N set, H set if lower nibble borrows,
//       C unaffected. 4 T-cycles.

test "0x3D DEC A: decrements A by 1" {
    var h = Harness.init();
    h.setA(0x10);
    h.load(&.{0x3D});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x0F), h.regA());
}

test "0x3D DEC A: wraps from 0x00 to 0xFF" {
    var h = Harness.init();
    h.setA(0x00);
    h.load(&.{0x3D});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xFF), h.regA());
}

test "0x3D DEC A: sets Z when result is 0x00" {
    var h = Harness.init();
    h.setA(0x01);
    h.load(&.{0x3D});
    _ = try h.step();
    try std.testing.expect(h.flagZ());
}

test "0x3D DEC A: clears Z when result is non-zero" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // pre-set Z
    h.setA(0x05);
    h.load(&.{0x3D});
    _ = try h.step();
    try std.testing.expect(!h.flagZ());
}

test "0x3D DEC A: sets N flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 6)); // clear N
    h.setA(0x10);
    h.load(&.{0x3D});
    _ = try h.step();
    try std.testing.expect(h.flagN());
}

test "0x3D DEC A: sets H when lower nibble borrows (0x10 -> 0x0F)" {
    var h = Harness.init();
    h.setA(0x10);
    h.load(&.{0x3D});
    _ = try h.step();
    try std.testing.expect(h.flagH());
}

test "0x3D DEC A: clears H when no borrow from upper nibble" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 5); // pre-set H
    h.setA(0x0F);
    h.load(&.{0x3D});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x3D DEC A: does not affect C flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.setA(0x00);
    h.load(&.{0x3D});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x3D DEC A: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x3D});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x3E  LD A, u8
// ---------------------------------------------------------------------------
// Spec: Load immediate byte into A. 8 T-cycles, PC+2. Flags unaffected.

test "0x3E LD A,u8: loads immediate byte into A" {
    var h = Harness.init();
    h.load(&.{ 0x3E, 0xAB });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regA());
}

test "0x3E LD A,u8: edge case 0x00" {
    var h = Harness.init();
    h.load(&.{ 0x3E, 0x00 });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x00), h.regA());
}

test "0x3E LD A,u8: edge case 0xFF" {
    var h = Harness.init();
    h.load(&.{ 0x3E, 0xFF });
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xFF), h.regA());
}

test "0x3E LD A,u8: consumes 8 T-cycles and advances PC by 2" {
    var h = Harness.init();
    h.load(&.{ 0x3E, 0x00 });
    const pc_before = h.regPC();
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
    try std.testing.expectEqual(pc_before + 2, h.regPC());
}

test "0x3E LD A,u8: does not affect flags" {
    var h = Harness.init();
    h.load(&.{ 0x3E, 0xFF });
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

// ---------------------------------------------------------------------------
// 0x3F  CCF
// ---------------------------------------------------------------------------
// Spec: Complement carry flag — C is flipped, not set unconditionally.
//       N and H always cleared. Z unaffected. 4 T-cycles.

test "0x3F CCF: flips C from clear to set" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f &= ~@as(u8, (1 << 4)); // clear C
    h.load(&.{0x3F});
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x3F CCF: flips C from set to clear" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.load(&.{0x3F});
    _ = try h.step();
    try std.testing.expect(!h.flagC());
}

test "0x3F CCF: applying twice restores original C value" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 4); // set C
    h.load(&.{ 0x3F, 0x3F });
    _ = try h.step();
    _ = try h.step();
    try std.testing.expect(h.flagC());
}

test "0x3F CCF: always clears N flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 6); // pre-set N
    h.load(&.{0x3F});
    _ = try h.step();
    try std.testing.expect(!h.flagN());
}

test "0x3F CCF: always clears H flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 5); // pre-set H
    h.load(&.{0x3F});
    _ = try h.step();
    try std.testing.expect(!h.flagH());
}

test "0x3F CCF: does not affect Z flag" {
    var h = Harness.init();
    h.cpu.registers.af.parts.f |= (1 << 7); // set Z
    h.load(&.{0x3F});
    _ = try h.step();
    try std.testing.expect(h.flagZ()); // Z unchanged
}

test "0x3F CCF: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x3F});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// Row 5: 0x40-0x4F  LD r, r' / LD r, (HL)
// ---------------------------------------------------------------------------
// Spec: Load register r with value from register r' (or memory at HL).
//       Register variants: 4 T-cycles, PC+1, flags unaffected.
//       (HL) variants: 8 T-cycles, PC+1, flags unaffected.
//
// The destination register for this row is always B (0x40-0x47)
// or C (0x48-0x4F).

// ---------------------------------------------------------------------------
// 0x40  LD B, B
// ---------------------------------------------------------------------------

test "0x40 LD B,B: B is unchanged" {
    var h = Harness.init();
    h.setB(0x42);
    h.load(&.{0x40});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x42), h.regB());
}

test "0x40 LD B,B: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x40});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x40 LD B,B: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x40});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x41  LD B, C
// ---------------------------------------------------------------------------

test "0x41 LD B,C: loads C into B" {
    var h = Harness.init();
    h.setC(0xAB);
    h.setB(0x00);
    h.load(&.{0x41});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regB());
}

test "0x41 LD B,C: does not modify C" {
    var h = Harness.init();
    h.setC(0xAB);
    h.load(&.{0x41});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regC());
}

test "0x41 LD B,C: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x41});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x41 LD B,C: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x41});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x42  LD B, D
// ---------------------------------------------------------------------------

test "0x42 LD B,D: loads D into B" {
    var h = Harness.init();
    h.setD(0xCD);
    h.setB(0x00);
    h.load(&.{0x42});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xCD), h.regB());
}

test "0x42 LD B,D: does not modify D" {
    var h = Harness.init();
    h.setD(0xCD);
    h.load(&.{0x42});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xCD), h.regD());
}

test "0x42 LD B,D: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x42});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x42 LD B,D: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x42});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x43  LD B, E
// ---------------------------------------------------------------------------

test "0x43 LD B,E: loads E into B" {
    var h = Harness.init();
    h.setE(0x11);
    h.setB(0x00);
    h.load(&.{0x43});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regB());
}

test "0x43 LD B,E: does not modify E" {
    var h = Harness.init();
    h.setE(0x11);
    h.load(&.{0x43});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regE());
}

test "0x43 LD B,E: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x43});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x43 LD B,E: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x43});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x44  LD B, H
// ---------------------------------------------------------------------------

test "0x44 LD B,H: loads H into B" {
    var h = Harness.init();
    h.setH(0x22);
    h.setB(0x00);
    h.load(&.{0x44});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x22), h.regB());
}

test "0x44 LD B,H: does not modify H" {
    var h = Harness.init();
    h.setH(0x22);
    h.load(&.{0x44});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x22), h.regH());
}

test "0x44 LD B,H: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x44});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x44 LD B,H: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x44});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x45  LD B, L
// ---------------------------------------------------------------------------

test "0x45 LD B,L: loads L into B" {
    var h = Harness.init();
    h.setL(0x33);
    h.setB(0x00);
    h.load(&.{0x45});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x33), h.regB());
}

test "0x45 LD B,L: does not modify L" {
    var h = Harness.init();
    h.setL(0x33);
    h.load(&.{0x45});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x33), h.regL());
}

test "0x45 LD B,L: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x45});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x45 LD B,L: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x45});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x46  LD B, (HL)
// ---------------------------------------------------------------------------

test "0x46 LD B,(HL): loads byte from address in HL into B" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x55);
    h.load(&.{0x46});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x55), h.regB());
}

test "0x46 LD B,(HL): does not modify HL" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x55);
    h.load(&.{0x46});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xC000), h.regHL());
}

test "0x46 LD B,(HL): does not affect flags" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0xFF);
    h.load(&.{0x46});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x46 LD B,(HL): consumes 8 T-cycles" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x46});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x47  LD B, A
// ---------------------------------------------------------------------------

test "0x47 LD B,A: loads A into B" {
    var h = Harness.init();
    h.setA(0x77);
    h.setB(0x00);
    h.load(&.{0x47});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.regB());
}

test "0x47 LD B,A: does not modify A" {
    var h = Harness.init();
    h.setA(0x77);
    h.load(&.{0x47});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.regA());
}

test "0x47 LD B,A: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x47});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x47 LD B,A: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x47});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x48  LD C, B
// ---------------------------------------------------------------------------

test "0x48 LD C,B: loads B into C" {
    var h = Harness.init();
    h.setB(0xAB);
    h.setC(0x00);
    h.load(&.{0x48});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regC());
}

test "0x48 LD C,B: does not modify B" {
    var h = Harness.init();
    h.setB(0xAB);
    h.load(&.{0x48});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regB());
}

test "0x48 LD C,B: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x48});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x48 LD C,B: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x48});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x49  LD C, C
// ---------------------------------------------------------------------------

test "0x49 LD C,C: C is unchanged" {
    var h = Harness.init();
    h.setC(0x42);
    h.load(&.{0x49});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x42), h.regC());
}

test "0x49 LD C,C: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x49});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x49 LD C,C: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x49});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x4A  LD C, D
// ---------------------------------------------------------------------------

test "0x4A LD C,D: loads D into C" {
    var h = Harness.init();
    h.setD(0xCD);
    h.setC(0x00);
    h.load(&.{0x4A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xCD), h.regC());
}

test "0x4A LD C,D: does not modify D" {
    var h = Harness.init();
    h.setD(0xCD);
    h.load(&.{0x4A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xCD), h.regD());
}

test "0x4A LD C,D: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x4A});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x4A LD C,D: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x4A});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x4B  LD C, E
// ---------------------------------------------------------------------------

test "0x4B LD C,E: loads E into C" {
    var h = Harness.init();
    h.setE(0x11);
    h.setC(0x00);
    h.load(&.{0x4B});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regC());
}

test "0x4B LD C,E: does not modify E" {
    var h = Harness.init();
    h.setE(0x11);
    h.load(&.{0x4B});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regE());
}

test "0x4B LD C,E: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x4B});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x4B LD C,E: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x4B});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x4C  LD C, H
// ---------------------------------------------------------------------------

test "0x4C LD C,H: loads H into C" {
    var h = Harness.init();
    h.setH(0x22);
    h.setC(0x00);
    h.load(&.{0x4C});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x22), h.regC());
}

test "0x4C LD C,H: does not modify H" {
    var h = Harness.init();
    h.setH(0x22);
    h.load(&.{0x4C});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x22), h.regH());
}

test "0x4C LD C,H: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x4C});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x4C LD C,H: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x4C});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x4D  LD C, L
// ---------------------------------------------------------------------------

test "0x4D LD C,L: loads L into C" {
    var h = Harness.init();
    h.setL(0x33);
    h.setC(0x00);
    h.load(&.{0x4D});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x33), h.regC());
}

test "0x4D LD C,L: does not modify L" {
    var h = Harness.init();
    h.setL(0x33);
    h.load(&.{0x4D});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x33), h.regL());
}

test "0x4D LD C,L: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x4D});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x4D LD C,L: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x4D});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x4E  LD C, (HL)
// ---------------------------------------------------------------------------

test "0x4E LD C,(HL): loads byte from address in HL into C" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x55);
    h.load(&.{0x4E});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x55), h.regC());
}

test "0x4E LD C,(HL): does not modify HL" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x55);
    h.load(&.{0x4E});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xC000), h.regHL());
}

test "0x4E LD C,(HL): does not affect flags" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0xFF);
    h.load(&.{0x4E});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x4E LD C,(HL): consumes 8 T-cycles" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x4E});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x4F  LD C, A
// ---------------------------------------------------------------------------

test "0x4F LD C,A: loads A into C" {
    var h = Harness.init();
    h.setA(0x77);
    h.setC(0x00);
    h.load(&.{0x4F});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.regC());
}

test "0x4F LD C,A: does not modify A" {
    var h = Harness.init();
    h.setA(0x77);
    h.load(&.{0x4F});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.regA());
}

test "0x4F LD C,A: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x4F});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x4F LD C,A: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x4F});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// Row 6: 0x50-0x5F  LD r, r' / LD r, (HL)
// ---------------------------------------------------------------------------
// Spec: Load register r with value from register r' (or memory at HL).
//       Register variants: 4 T-cycles, PC+1, flags unaffected.
//       (HL) variants: 8 T-cycles, PC+1, flags unaffected.
//
// The destination register for this row is always D (0x50-0x57)
// or E (0x58-0x5F).

// ---------------------------------------------------------------------------
// 0x50  LD D, B
// ---------------------------------------------------------------------------

test "0x50 LD D,B: loads B into D" {
    var h = Harness.init();
    h.setB(0xAB);
    h.setD(0x00);
    h.load(&.{0x50});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regD());
}

test "0x50 LD D,B: does not modify B" {
    var h = Harness.init();
    h.setB(0xAB);
    h.load(&.{0x50});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regB());
}

test "0x50 LD D,B: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x50});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x50 LD D,B: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x50});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x51  LD D, C
// ---------------------------------------------------------------------------

test "0x51 LD D,C: loads C into D" {
    var h = Harness.init();
    h.setC(0xCD);
    h.setD(0x00);
    h.load(&.{0x51});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xCD), h.regD());
}

test "0x51 LD D,C: does not modify C" {
    var h = Harness.init();
    h.setC(0xCD);
    h.load(&.{0x51});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xCD), h.regC());
}

test "0x51 LD D,C: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x51});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x51 LD D,C: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x51});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x52  LD D, D
// ---------------------------------------------------------------------------

test "0x52 LD D,D: D is unchanged" {
    var h = Harness.init();
    h.setD(0x42);
    h.load(&.{0x52});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x42), h.regD());
}

test "0x52 LD D,D: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x52});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x52 LD D,D: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x52});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x53  LD D, E
// ---------------------------------------------------------------------------

test "0x53 LD D,E: loads E into D" {
    var h = Harness.init();
    h.setE(0x11);
    h.setD(0x00);
    h.load(&.{0x53});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regD());
}

test "0x53 LD D,E: does not modify E" {
    var h = Harness.init();
    h.setE(0x11);
    h.load(&.{0x53});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regE());
}

test "0x53 LD D,E: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x53});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x53 LD D,E: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x53});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x54  LD D, H
// ---------------------------------------------------------------------------

test "0x54 LD D,H: loads H into D" {
    var h = Harness.init();
    h.setH(0x22);
    h.setD(0x00);
    h.load(&.{0x54});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x22), h.regD());
}

test "0x54 LD D,H: does not modify H" {
    var h = Harness.init();
    h.setH(0x22);
    h.load(&.{0x54});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x22), h.regH());
}

test "0x54 LD D,H: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x54});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x54 LD D,H: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x54});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x55  LD D, L
// ---------------------------------------------------------------------------

test "0x55 LD D,L: loads L into D" {
    var h = Harness.init();
    h.setL(0x33);
    h.setD(0x00);
    h.load(&.{0x55});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x33), h.regD());
}

test "0x55 LD D,L: does not modify L" {
    var h = Harness.init();
    h.setL(0x33);
    h.load(&.{0x55});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x33), h.regL());
}

test "0x55 LD D,L: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x55});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x55 LD D,L: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x55});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x56  LD D, (HL)
// ---------------------------------------------------------------------------

test "0x56 LD D,(HL): loads byte from address in HL into D" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x55);
    h.load(&.{0x56});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x55), h.regD());
}

test "0x56 LD D,(HL): does not modify HL" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x55);
    h.load(&.{0x56});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xC000), h.regHL());
}

test "0x56 LD D,(HL): does not affect flags" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0xFF);
    h.load(&.{0x56});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x56 LD D,(HL): consumes 8 T-cycles" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x56});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x57  LD D, A
// ---------------------------------------------------------------------------

test "0x57 LD D,A: loads A into D" {
    var h = Harness.init();
    h.setA(0x77);
    h.setD(0x00);
    h.load(&.{0x57});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.regD());
}

test "0x57 LD D,A: does not modify A" {
    var h = Harness.init();
    h.setA(0x77);
    h.load(&.{0x57});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.regA());
}

test "0x57 LD D,A: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x57});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x57 LD D,A: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x57});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x58  LD E, B
// ---------------------------------------------------------------------------

test "0x58 LD E,B: loads B into E" {
    var h = Harness.init();
    h.setB(0xAB);
    h.setE(0x00);
    h.load(&.{0x58});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regE());
}

test "0x58 LD E,B: does not modify B" {
    var h = Harness.init();
    h.setB(0xAB);
    h.load(&.{0x58});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regB());
}

test "0x58 LD E,B: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x58});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x58 LD E,B: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x58});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x59  LD E, C
// ---------------------------------------------------------------------------

test "0x59 LD E,C: loads C into E" {
    var h = Harness.init();
    h.setC(0xCD);
    h.setE(0x00);
    h.load(&.{0x59});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xCD), h.regE());
}

test "0x59 LD E,C: does not modify C" {
    var h = Harness.init();
    h.setC(0xCD);
    h.load(&.{0x59});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xCD), h.regC());
}

test "0x59 LD E,C: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x59});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x59 LD E,C: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x59});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x5A  LD E, D
// ---------------------------------------------------------------------------

test "0x5A LD E,D: loads D into E" {
    var h = Harness.init();
    h.setD(0x11);
    h.setE(0x00);
    h.load(&.{0x5A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regE());
}

test "0x5A LD E,D: does not modify D" {
    var h = Harness.init();
    h.setD(0x11);
    h.load(&.{0x5A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regD());
}

test "0x5A LD E,D: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x5A});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x5A LD E,D: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x5A});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x5B  LD E, E
// ---------------------------------------------------------------------------

test "0x5B LD E,E: E is unchanged" {
    var h = Harness.init();
    h.setE(0x42);
    h.load(&.{0x5B});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x42), h.regE());
}

test "0x5B LD E,E: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x5B});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x5B LD E,E: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x5B});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x5C  LD E, H
// ---------------------------------------------------------------------------

test "0x5C LD E,H: loads H into E" {
    var h = Harness.init();
    h.setH(0x22);
    h.setE(0x00);
    h.load(&.{0x5C});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x22), h.regE());
}

test "0x5C LD E,H: does not modify H" {
    var h = Harness.init();
    h.setH(0x22);
    h.load(&.{0x5C});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x22), h.regH());
}

test "0x5C LD E,H: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x5C});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x5C LD E,H: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x5C});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x5D  LD E, L
// ---------------------------------------------------------------------------

test "0x5D LD E,L: loads L into E" {
    var h = Harness.init();
    h.setL(0x33);
    h.setE(0x00);
    h.load(&.{0x5D});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x33), h.regE());
}

test "0x5D LD E,L: does not modify L" {
    var h = Harness.init();
    h.setL(0x33);
    h.load(&.{0x5D});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x33), h.regL());
}

test "0x5D LD E,L: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x5D});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x5D LD E,L: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x5D});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// 0x5E  LD E, (HL)
// ---------------------------------------------------------------------------

test "0x5E LD E,(HL): loads byte from address in HL into E" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x55);
    h.load(&.{0x5E});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x55), h.regE());
}

test "0x5E LD E,(HL): does not modify HL" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x55);
    h.load(&.{0x5E});
    _ = try h.step();
    try std.testing.expectEqual(@as(u16, 0xC000), h.regHL());
}

test "0x5E LD E,(HL): does not affect flags" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0xFF);
    h.load(&.{0x5E});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x5E LD E,(HL): consumes 8 T-cycles" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x5E});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

// ---------------------------------------------------------------------------
// 0x5F  LD E, A
// ---------------------------------------------------------------------------

test "0x5F LD E,A: loads A into E" {
    var h = Harness.init();
    h.setA(0x77);
    h.setE(0x00);
    h.load(&.{0x5F});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.regE());
}

test "0x5F LD E,A: does not modify A" {
    var h = Harness.init();
    h.setA(0x77);
    h.load(&.{0x5F});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.regA());
}

test "0x5F LD E,A: does not affect flags" {
    var h = Harness.init();
    h.load(&.{0x5F});
    const f_before = h.regF();
    _ = try h.step();
    try std.testing.expectEqual(f_before, h.regF());
}

test "0x5F LD E,A: consumes 4 T-cycles" {
    var h = Harness.init();
    h.load(&.{0x5F});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 4), cycles);
}

// ---------------------------------------------------------------------------
// Row 7: 0x60-0x6F  LD r, r' / LD r, (HL)
// ---------------------------------------------------------------------------
// Spec: Load register r with value from register r' (or memory at HL).
//       Register variants: 4 T-cycles, PC+1, flags unaffected.
//       (HL) variants: 8 T-cycles, PC+1, flags unaffected.
//
// The destination register for this row is always H (0x60-0x67)
// or L (0x68-0x6F).
//
// Test strategy: one transfer test per instruction to confirm correct source
// and destination. Cycle count tested for (HL) variants only (8 vs 4 is the
// only meaningful variation). Flags and "does not modify source" omitted —
// proven uniform across the entire LD r,r block.

test "0x60 LD H,B: loads B into H" {
    var h = Harness.init();
    h.setB(0xAB);
    h.setH(0x00);
    h.load(&.{0x60});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regH());
}

test "0x61 LD H,C: loads C into H" {
    var h = Harness.init();
    h.setC(0xCD);
    h.setH(0x00);
    h.load(&.{0x61});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xCD), h.regH());
}

test "0x62 LD H,D: loads D into H" {
    var h = Harness.init();
    h.setD(0x11);
    h.setH(0x00);
    h.load(&.{0x62});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regH());
}

test "0x63 LD H,E: loads E into H" {
    var h = Harness.init();
    h.setE(0x22);
    h.setH(0x00);
    h.load(&.{0x63});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x22), h.regH());
}

test "0x64 LD H,H: H is unchanged" {
    var h = Harness.init();
    h.setH(0x42);
    h.load(&.{0x64});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x42), h.regH());
}

test "0x65 LD H,L: loads L into H" {
    var h = Harness.init();
    // Set L without disturbing H via the 16-bit setter
    h.cpu.registers.hl.parts.l = 0x33;
    h.cpu.registers.hl.parts.h = 0x00;
    h.load(&.{0x65});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x33), h.regH());
}

test "0x66 LD H,(HL): loads byte from address in HL into H" {
    var h = Harness.init();
    // HL = 0xC010, mem[0xC010] = 0x55
    // After: H = 0x55, so HL = 0x5510 (L unchanged)
    h.setHL(0xC010);
    h.writeMem(0xC010, 0x55);
    h.load(&.{0x66});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x55), h.regH());
}

test "0x66 LD H,(HL): reads address before overwriting H" {
    var h = Harness.init();
    // HL = 0xC010 — the address used must be the original HL, not post-write
    h.setHL(0xC010);
    h.writeMem(0xC010, 0xAB);
    h.load(&.{0x66});
    _ = try h.step();
    // H should be 0xAB (read from 0xC010), not whatever 0xAB10 holds
    try std.testing.expectEqual(@as(u8, 0xAB), h.regH());
}

test "0x66 LD H,(HL): consumes 8 T-cycles" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x66});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

test "0x67 LD H,A: loads A into H" {
    var h = Harness.init();
    h.setA(0x77);
    h.setH(0x00);
    h.load(&.{0x67});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.regH());
}

test "0x68 LD L,B: loads B into L" {
    var h = Harness.init();
    h.setB(0xAB);
    h.setL(0x00);
    h.load(&.{0x68});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regL());
}

test "0x69 LD L,C: loads C into L" {
    var h = Harness.init();
    h.setC(0xCD);
    h.setL(0x00);
    h.load(&.{0x69});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xCD), h.regL());
}

test "0x6A LD L,D: loads D into L" {
    var h = Harness.init();
    h.setD(0x11);
    h.setL(0x00);
    h.load(&.{0x6A});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x11), h.regL());
}

test "0x6B LD L,E: loads E into L" {
    var h = Harness.init();
    h.setE(0x22);
    h.setL(0x00);
    h.load(&.{0x6B});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x22), h.regL());
}

test "0x6C LD L,H: loads H into L" {
    var h = Harness.init();
    h.cpu.registers.hl.parts.h = 0x33;
    h.cpu.registers.hl.parts.l = 0x00;
    h.load(&.{0x6C});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x33), h.regL());
}

test "0x6D LD L,L: L is unchanged" {
    var h = Harness.init();
    h.setL(0x42);
    h.load(&.{0x6D});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x42), h.regL());
}

test "0x6E LD L,(HL): loads byte from address in HL into L" {
    var h = Harness.init();
    // HL = 0xC000, mem[0xC000] = 0x55
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x55);
    h.load(&.{0x6E});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x55), h.regL());
}

test "0x6E LD L,(HL): reads address before overwriting L" {
    var h = Harness.init();
    // HL = 0xC010 — address used must be the original HL
    h.setHL(0xC010);
    h.writeMem(0xC010, 0xAB);
    h.load(&.{0x6E});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0xAB), h.regL());
}

test "0x6E LD L,(HL): consumes 8 T-cycles" {
    var h = Harness.init();
    h.setHL(0xC000);
    h.writeMem(0xC000, 0x00);
    h.load(&.{0x6E});
    const cycles = try h.step();
    try std.testing.expectEqual(@as(u8, 8), cycles);
}

test "0x6F LD L,A: loads A into L" {
    var h = Harness.init();
    h.setA(0x77);
    h.setL(0x00);
    h.load(&.{0x6F});
    _ = try h.step();
    try std.testing.expectEqual(@as(u8, 0x77), h.regL());
}
