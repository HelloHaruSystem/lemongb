const std = @import("std");
const state = @import("../core/cpu.zig").CpuState;

pub fn trace(writer: *std.Io.Writer, cpu_state: state) !void {
    try writer.print("A:{X:0>2} F:{X:0>2} B:{X:0>2} C:{X:0>2} D:{X:0>2} E:{X:0>2} H:{X:0>2} L:{X:0>2} SP:{X:0>4} PC:{X:0>4} PCMEM:{X:0>2},{X:0>2},{X:0>2},{X:0>2}\n", .{
        cpu_state.registers.af.parts.a,
        cpu_state.registers.af.parts.f,
        cpu_state.registers.bc.parts.b,
        cpu_state.registers.bc.parts.c,
        cpu_state.registers.de.parts.d,
        cpu_state.registers.de.parts.e,
        cpu_state.registers.hl.parts.h,
        cpu_state.registers.hl.parts.l,
        cpu_state.registers.sp,
        cpu_state.registers.pc,
        cpu_state.pcmem[0],
        cpu_state.pcmem[1],
        cpu_state.pcmem[2],
        cpu_state.pcmem[3],
    });
}
