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
            .rom_only => if (address <= 0x7FFF) return self.rom_data[address] else return 0xFF,
            .mbc1 => |state| return state.read(self.rom_data, address),
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
pub const Mbc1State = struct {
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
            0x0000...0x1FFF => { // ram enable/disable
                if ((value & 0x0F) == 0xA) self.ram_enabled = true else self.ram_enabled = false;
            },
            0x2000...0x3FFF => { // ROM Bank number
                const bank = value & 0x1F;
                self.rom_bank = if (bank == 0) 1 else bank;
            },
            0x4000...0x5FFF => { // Ram bank number or upper bits of ROM bank number
                self.ram_bank = value & 0x03;
            },
            0x6000...0x7FFF => { // Banking mode select
                self.banking_mode = @truncate(value & 0x01);
            },
            0xA000...0xBFFF => { // actual ram space
                if (!self.ram_enabled) return;

                if (self.banking_mode == 0) {
                    const idx = @as(usize, address - 0xA000);
                    self.ram_data[idx] = value;
                } else {
                    const idx = (@as(usize, self.ram_bank) * 0x2000) + (@as(usize, address - 0xA000));
                    self.ram_data[idx] = value;
                }
            },
            else => {},
        }
    }

    // handle read
    pub fn read(self: *const Mbc1State, rom_data: []u8, address: u16) u8 {
        switch (address) {
            0x0000...0x3FFF => { // Rom bank  x0
                if (self.banking_mode == 0) return rom_data[@as(usize, address)];

                const idx = (@as(usize, (self.ram_bank << 5)) * 0x4000) | @as(usize, address);
                return rom_data[idx];
            },
            0x4000...0x7FFF => { // rom bank 01-7F
                const bank = @as(usize, (self.ram_bank << 5) | self.rom_bank);
                const idx = (bank * 0x4000) + (@as(usize, address - 0x4000));
                return rom_data[idx];
            },
            0xA000...0xBFFF => { // ram bank 00-03 (if any)
                if (!self.ram_enabled) return 0xFF;

                if (self.banking_mode == 0) {
                    const idx = @as(usize, address - 0xA000);
                    return self.ram_data[idx];
                } else {
                    const idx = (@as(usize, self.ram_bank) * 0x2000) + (@as(usize, address - 0xA000));
                    return self.ram_data[idx];
                }
            },
            else => return 0xFF,
        }
    }
};
