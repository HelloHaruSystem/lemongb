const std = @import("std");
const Logger = @import("debug/logger.zig").Logger;
const LogLevel = @import("debug/logger.zig").LogLevel;
const Gameboy = @import("core/gameboy.zig").Gameboy;

pub fn main() !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const logger = Logger.init(.{ .level = .debug });
    try logger.log(stdout, .debug, "Hello, World!");

    const gameboy = Gameboy.init();
    try logger.log(stdout, .debug, "Gameboy initialized!");
    _ = gameboy;
}
