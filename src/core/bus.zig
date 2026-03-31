pub const Bus = struct {
    // 65,536 / 64 KB
    // 0x0000 - 0x3FFF: ROM Bank 00 (16 KiB)
    // 0x4000 - 0x7FFF: ROM Bank 01 (16 KiB)
    // 0x8000 - 0x9FFF: Video RAM (8 KiB)
    // 0xA000 - 0xBFFF: External RAM (8 KiB)
    // 0xC000 - 0xCFFF: Work RAM (4 KiB)
    // 0xD000 - 0xDFFF: Work RAM (4 KiB)
    // 0xE000 - 0xFDFF: Echo RAM (mirrors 0xC000 - 0xDDFF)
    // 0xFE00 - 0xFE9F: Object Attribute Memory (OAM)
    // 0xFEA0 - 0xFEFF: Not usable
    // 0xFF00 - 0xFF7F: I/O Registers
    // 0xFF80 - 0xFFFE: High RAM
    // 0xFFFF:          Interrupt Enable Register (IE)
    memory: [0xFFFF + 1]u8,

    pub fn init() Bus {
        return Bus{
            .memory = [_]u8{0} ** (0xFFFF + 1),
        };
    }

    pub fn read(self: *Bus, address: u16) u8 {
        // for now just return the data at the location
        // in the future handle the regions differently
        switch (address) {
            0x0000...0x3FFF => return self.memory[address],
            0x4000...0x7FFF => return self.memory[address],
            0x8000...0x9FFF => return self.memory[address],
            0xA000...0xBFFF => return self.memory[address],
            0xC000...0xCFFF => return self.memory[address],
            0xD000...0xDFFF => return self.memory[address],
            0xE000...0xFDFF => return self.memory[address - 0x2000], // echo address subtracting 0x2000 maps it to the corresponding work ram adress
            0xFE00...0xFE9F => return self.memory[address],
            0xFEA0...0xFEFF => return 0xFF, // not usable region just returns 0xFF for now
            0xFF00...0xFF7F => return self.memory[address],
            0xFF80...0xFFFE => return self.memory[address],
            0xFFFF => return self.memory[address],
        }
    }

    pub fn write(self: *Bus, address: u16, value: u8) void {
        // simple for now
        // rom bank 00 and bank 01 is read only
        switch (address) {
            0x0000...0x7FFF => {}, // rom bank 00 and bank 01 is read only
            0xE000...0xFDFF => self.memory[address - 0x2000] = value, // echo address mirrors work ram so we write to the corresponding work ram address
            0xFEA0...0xFEFF => {}, // not usable region undefined/weird behavior on real hardware
            else => self.memory[address] = value,
        }
    }
};
