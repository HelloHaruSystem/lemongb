const Cpu = @import("cpu.zig").Cpu;
const Bus = @import("bus.zig").Bus;

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
};
