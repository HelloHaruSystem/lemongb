const std = @import("std");
const testing = std.testing;
const Cartridge = @import("cartridge.zig").Cartridge;
const Mbc1State = @import("cartridge.zig").Mbc1State;
const Bus = @import("bus.zig").Bus;

// ---------------------------------------------------------------------------
// AI generated!
// MBC1 external RAM enable/disable
// ---------------------------------------------------------------------------

fn makeMbc1(rom: []u8, ram: []u8) Cartridge {
    return Cartridge{
        .rom_data = rom,
        .cartridge_type = .{ .mbc1 = Mbc1State.init(ram) },
    };
}

test "external RAM is disabled by default" {
    var rom = [_]u8{0} ** 0x8000;
    var ram = [_]u8{0} ** 0x2000;
    var cart = makeMbc1(&rom, &ram);

    try testing.expectEqual(@as(u8, 0xFF), cart.read(0xA000));
}

test "writing 0x0A to the enable range enables external RAM" {
    var rom = [_]u8{0} ** 0x8000;
    var ram = [_]u8{0} ** 0x2000;
    var cart = makeMbc1(&rom, &ram);

    cart.write(0x0000, 0x0A);
    cart.write(0xA000, 0x42);

    try testing.expectEqual(@as(u8, 0x42), cart.read(0xA000));
}

test "writing a non-0x0A value to the enable range disables external RAM" {
    var rom = [_]u8{0} ** 0x8000;
    var ram = [_]u8{0} ** 0x2000;
    var cart = makeMbc1(&rom, &ram);

    cart.write(0x0000, 0x0A); // enable
    cart.write(0xA000, 0x42);
    cart.write(0x0000, 0x00); // disable

    try testing.expectEqual(@as(u8, 0xFF), cart.read(0xA000));
}

test "writes to external RAM while disabled are discarded" {
    var rom = [_]u8{0} ** 0x8000;
    var ram = [_]u8{0} ** 0x2000;
    var cart = makeMbc1(&rom, &ram);

    cart.write(0xA000, 0x99); // disabled, should be discarded
    cart.write(0x0000, 0x0A); // enable
    try testing.expectEqual(@as(u8, 0x00), cart.read(0xA000));
}

test "enable range boundary: 0x1FFF enables, 0x2000 does not" {
    var rom = [_]u8{0} ** 0x8000;
    var ram = [_]u8{0} ** 0x2000;
    var cart = makeMbc1(&rom, &ram);

    cart.write(0x2000, 0x0A); // outside enable range (ROM bank select)
    cart.write(0xA000, 0x55);
    try testing.expectEqual(@as(u8, 0xFF), cart.read(0xA000)); // still disabled

    cart.write(0x1FFF, 0x0A); // inside enable range
    cart.write(0xA000, 0x55);
    try testing.expectEqual(@as(u8, 0x55), cart.read(0xA000));
}

test "RAM read/write spans the full 0xA000-0xBFFF window" {
    var rom = [_]u8{0} ** 0x8000;
    var ram = [_]u8{0} ** 0x2000;
    var cart = makeMbc1(&rom, &ram);

    cart.write(0x0000, 0x0A);
    cart.write(0xA000, 0x11);
    cart.write(0xBFFF, 0x22);

    try testing.expectEqual(@as(u8, 0x11), cart.read(0xA000));
    try testing.expectEqual(@as(u8, 0x22), cart.read(0xBFFF));
}

test "Bus delegates external RAM access to the cartridge" {
    var rom = [_]u8{0} ** 0x8000;
    var ram = [_]u8{0} ** 0x2000;
    var cart = makeMbc1(&rom, &ram);
    var bus = Bus.init();
    bus.loadCartridge(&cart);

    bus.write(0x0000, 0x0A); // enable via bus
    bus.write(0xA000, 0x77);

    try testing.expectEqual(@as(u8, 0x77), bus.read(0xA000));
}

// ---------------------------------------------------------------------------
// AI generated!
// MBC1 ROM bank switching
// ---------------------------------------------------------------------------

test "fixed ROM window reads from bank 0 in mode 0" {
    var rom = [_]u8{0} ** 0x8000;
    var ram = [_]u8{0} ** 0x2000;
    rom[0x0100] = 0xAA;
    var cart = makeMbc1(&rom, &ram);

    try testing.expectEqual(@as(u8, 0xAA), cart.read(0x0100));
}

test "switchable ROM window defaults to bank 1" {
    var rom = [_]u8{0} ** 0x8000;
    var ram = [_]u8{0} ** 0x2000;
    rom[0x4000] = 0xBB; // first byte of bank 1 in rom_data
    var cart = makeMbc1(&rom, &ram);

    try testing.expectEqual(@as(u8, 0xBB), cart.read(0x4000));
}

test "writing to ROM bank register switches active bank" {
    var rom = [_]u8{0} ** (3 * 0x4000);
    var ram = [_]u8{0} ** 0x2000;
    rom[0x4000] = 0xBB; // bank 1, offset 0
    rom[0x8000] = 0xCC; // bank 2, offset 0
    var cart = makeMbc1(&rom, &ram);

    try testing.expectEqual(@as(u8, 0xBB), cart.read(0x4000)); // default bank 1
    cart.write(0x2000, 0x02);
    try testing.expectEqual(@as(u8, 0xCC), cart.read(0x4000)); // now bank 2
}

test "writing 0 to ROM bank register selects bank 1" {
    var rom = [_]u8{0} ** 0x8000;
    var ram = [_]u8{0} ** 0x2000;
    rom[0x4000] = 0xDD; // bank 1, offset 0
    var cart = makeMbc1(&rom, &ram);

    cart.write(0x2000, 0x00); // 0 should remap to 1
    try testing.expectEqual(@as(u8, 0xDD), cart.read(0x4000));
}

test "fixed ROM window unaffected by bank switch in mode 0" {
    var rom = [_]u8{0} ** (3 * 0x4000);
    var ram = [_]u8{0} ** 0x2000;
    rom[0x0100] = 0xAA;
    var cart = makeMbc1(&rom, &ram);

    cart.write(0x2000, 0x02); // switch to bank 2
    try testing.expectEqual(@as(u8, 0xAA), cart.read(0x0100)); // fixed window still bank 0
}
