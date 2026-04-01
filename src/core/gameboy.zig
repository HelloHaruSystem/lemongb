const Cpu = @import("cpu.zig").Cpu;
const Bus = @import("bus.zig").Bus;
const Cartridge = @import("cartridge.zig").Cartridge;

pub const Gameboy = struct {
    cpu: Cpu,
    bus: Bus,
    cycles: u64,

    pub fn init() Gameboy {
        return Gameboy{
            .cpu = Cpu.init(),
            .bus = Bus.init(),
            .cycles = 0,
        };
    }

    pub fn loadCartridge(self: *Gameboy, cartridge: *const Cartridge) void {
        self.bus.loadCartridge(cartridge);
    }
};
