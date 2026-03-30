const std = @import("std");

pub const Logger = struct {
    level: LogLevel,

    pub fn init(config: Config) Logger {
        return Logger{ .level = config.level };
    }

    pub fn log(self: Logger, writer: *std.Io.Writer, level: LogLevel, message: []const u8) !void {
        if (@intFromEnum(self.level) < @intFromEnum(level)) {
            return;
        }

        const log_level = levelToString(level);
        try writer.print("[{s}] {s}\n", .{ log_level, message });
    }
};

pub const LogLevel = enum {
    err,
    warn,
    info,
    debug,
};

pub const Config = struct {
    level: LogLevel = .warn,
};

fn levelToString(level: LogLevel) []const u8 {
    return switch (level) {
        .err => "ERROR",
        .warn => "WARNING",
        .info => "INFO",
        .debug => "DEBUG",
    };
}
