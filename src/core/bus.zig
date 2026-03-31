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
};
