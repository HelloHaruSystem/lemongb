const std = @import("std");

pub const Tracer = struct {
    pub fn Trace(self: Tracer, writer: *std.Io.Writer) !void {
        _ = self;
        try writer.print("A:{d} F:{d} B:{d} C:{d} D:{d} E:{d} H:{d} L:{d} SP:{d} PC:{d} PCMEM:{d}\n", .{});
    }
};
