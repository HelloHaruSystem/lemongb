const std = @import("std");
const testing = std.testing;
const Cartridge = @import("cartridge.zig").Cartridge;
const Bus = @import("bus.zig").Bus;

// ---------------------------------------------------------------------------
// AI generated!
// MBC1 external RAM enable/disable
//
// Assumes: CartridgeType has an `.mbc1` variant, and Cartridge has
// `ram: []u8` + `ram_enabled: bool` fields. Adjust names here if your
// implementation differs.
// ---------------------------------------------------------------------------

fn makeMbc1(rom: []u8, ram: []u8) Cartridge {
    return Cartridge{
        .rom_data = rom,
        .ram_data = ram,
        .ram_enabled = false,
        .cartridge_type = .mbc1,
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
    cart.write(0xA000, 0x42); // store a byte while enabled
    cart.write(0x0000, 0x00); // disable

    try testing.expectEqual(@as(u8, 0xFF), cart.read(0xA000)); // back to open-bus
}

test "writes to external RAM while disabled are discarded" {
    var rom = [_]u8{0} ** 0x8000;
    var ram = [_]u8{0} ** 0x2000;
    var cart = makeMbc1(&rom, &ram);

    cart.write(0xA000, 0x99); // disabled, should be discarded
    cart.write(0x0000, 0x0A); // enable
    try testing.expectEqual(@as(u8, 0x00), cart.read(0xA000)); // untouched, not 0x99
}

test "enable range boundary: 0x1FFF enables, 0x2000 does not" {
    var rom = [_]u8{0} ** 0x8000;
    var ram = [_]u8{0} ** 0x2000;
    var cart = makeMbc1(&rom, &ram);

    cart.write(0x2000, 0x0A); // outside enable range (ROM bank select on MBC1)
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
