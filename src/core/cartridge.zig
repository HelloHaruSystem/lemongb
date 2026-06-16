const std = @import("std");

// 8MiB max rom size acording to pan docs
const max_rom_size: usize = 8 * 1024 * 1024;

pub const CartridgeError = error{
    RomTooSmall,
    InvalidHeader,
    UnsupportedCartridgeType, // used while the emulater is still under developing
};

pub const CartridgeType = union(enum) {
    rom_only: void,
};

pub const Cartridge = struct {
    rom_data: []u8,
    ram_data: []u8,
    ram_enabled: bool,
    cartridge_type: CartridgeType,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, cartridge_path: []const u8) !Cartridge {
        const rom_contents = try std.Io.Dir.cwd().readFileAlloc(io, cartridge_path, allocator, std.Io.Limit.limited(max_rom_size));

        // check header length the rom header is from 0x0100—0x014F
        if (rom_contents.len < 0x0150) return CartridgeError.RomTooSmall;

        const mbc_type_data = rom_contents[0x0147];
        const ram_size = try getRamSize(rom_contents[0x0149]);

        // check if the rom type is supported
        // rom only supported for now (0x00)
        const cartridge_type = try getMbcType(mbc_type_data);

        return Cartridge{
            .rom_data = rom_contents,
            .ram_data = [ram_size]u8,
            .ram_enabled = false,
            .cartridge_type = cartridge_type,
        };
    }

    pub fn read(self: *Cartridge, address: u16) u8 {
        switch (self.cartridge_type) {
            .rom_only => {
                if (address <= 0x7FFF) return self.rom_data[address] else return 0xFF;
            },
        }
    }

    pub fn write(self: *Cartridge, address: u16, value: u8) void {
        switch (self.cartridge_type) {
            .rom_only => {
                // throw away parameter while other types are not implemented
                _ = .{ address, value };
            },
        }
    }

    fn getMbcType(mbc_type: u8) !CartridgeType {
        return switch (mbc_type) {
            0x00 => CartridgeType.rom_only,
            else => return CartridgeError.UnsupportedCartridgeType,
        };
    }

    fn getRamSize(ram_type: u8) !u8 {
        return switch (ram_type) {
            0x00 => 0,
            0x01 => 0,
            0x02 => 8192,
            0x03 => 32768,
            0x04 => 131072,
            0x05 => 65536,
            else => CartridgeError.InvalidHeader,
        };
    }

    // MBC Structs
    const Mbc1State = struct {
        rom_bank: u8,
        ram_bank: u8,
        ram_data: []u8,
        ram_enabled: bool,
    };
};
