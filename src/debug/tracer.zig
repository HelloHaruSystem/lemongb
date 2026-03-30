const std = @import("std");
const state = @import("../core/cpu.zig").CpuState;

pub fn trace(writer: *std.Io.Writer, cpu_state: state) !void {
    try writer.print("A:{X:0>2} F:{X:0>2} B:{X:0>2} C:{X:0>2} D:{X:0>2} E:{X:0>2} H:{X:0>2} L:{X:0>2} SP:{X:0>4} PC:{X:0>4} PCMEM:{X:0>2},{X:0>2},{X:0>2},{X:0>2}\n", .{
        cpu_state.a,
        cpu_state.f,
        cpu_state.b,
        cpu_state.c,
        cpu_state.d,
        cpu_state.e,
        cpu_state.h,
        cpu_state.l,
        cpu_state.sp,
        cpu_state.pc,
        cpu_state.pcmem[0],
        cpu_state.pcmem[1],
        cpu_state.pcmem[2],
        cpu_state.pcmem[3],
    });
}
