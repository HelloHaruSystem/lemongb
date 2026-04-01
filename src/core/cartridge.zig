const std = @import("std");

// 8MiB max rom size acording to pan docs
const max_rom_size = 8 * 1024 * 1024;

pub const CartridgeError = error{
    RomTooSmall,
    InvalidHeader,
};

pub const Cartridge = struct {
    rom_data: []u8,
    cartridge_type: u8,

    pub fn init(allocator: std.mem.Allocator, cartridge_path: []const u8) !Cartridge {
        const rom_contents = try std.fs.cwd().readFileAlloc(allocator, cartridge_path, max_rom_size);

        // check header length the rom header is from 0x0100—0x014F
        if (rom_contents.len < 0x0150) return CartridgeError.RomTooSmall;

        const cartridge_type = rom_contents[0x0147];

        return Cartridge{
            .rom_data = rom_contents,
            .cartridge_type = cartridge_type,
        };
    }
};
