const std = @import("std");

// 8MiB max rom size acording to pan docs
const max_rom_size: usize = 8 * 1024 * 1024;

pub const CartridgeError = error{
    RomTooSmall,
    InvalidHeader,
    UnsupportedCartridgeType, // used while the emulater is still under developing
};

pub const Cartridge = struct {
    rom_data: []u8,
    cartridge_type: CartridgeType,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, cartridge_path: []const u8) !Cartridge {
        const rom_contents = try std.Io.Dir.cwd().readFileAlloc(io, cartridge_path, allocator, std.Io.Limit.limited(max_rom_size));

        // check header length the rom header is from 0x0100—0x014F
        if (rom_contents.len < 0x0150) return CartridgeError.RomTooSmall;

        const mbc_type_data = rom_contents[0x0147];
        const ram_size = @as(usize, try getRamSize(rom_contents[0x0149]));
        const ram = try allocator.alloc(u8, ram_size);

        // check if the rom type is supported
        // rom only supported for now (0x00)
        const cartridge_type = try getMbcType(mbc_type_data, ram);

        return Cartridge{
            .rom_data = rom_contents,
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
            .rom_only => {},
            .mbc1 => |*state| state.*.write(address, value),
        }
    }

    fn getMbcType(mbc_type: u8, ram: []u8) !CartridgeType {
        return switch (mbc_type) {
            0x00 => CartridgeType.rom_only,
            0x01...0x03 => CartridgeType{ .mbc1 = Mbc1State.init(ram) },
            else => return CartridgeError.UnsupportedCartridgeType,
        };
    }

    fn getRamSize(ram_type: u8) !u32 {
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
};

pub const CartridgeType = union(enum) {
    rom_only: void,
    mbc1: Mbc1State,
};

// MBC Structs
const Mbc1State = struct {
    rom_bank: u8,
    ram_bank: u8,
    ram_data: []u8,
    ram_enabled: bool,
    banking_mode: u1,

    pub fn init(ram_data: []u8) Mbc1State {
        return Mbc1State{
            .rom_bank = 1,
            .ram_bank = 0,
            .ram_data = ram_data,
            .ram_enabled = false,
            .banking_mode = 0,
        };
    }

    // handle write
    pub fn write(self: *Mbc1State, address: u16, value: u8) void {
        switch (address) {
            0x0000...0x1FFF => { // ram enable/disable (write only)
                if ((value & 0x0F) == 0xA) self.ram_enabled = true else self.ram_enabled = false;
            },
            0x2000...0x3FFF => { // ROM Bank number (write only)
                const bank = value & 0x1F;
                self.rom_bank = if (bank == 0) 1 else bank;
            },
            else => {},
        }
    }
};
