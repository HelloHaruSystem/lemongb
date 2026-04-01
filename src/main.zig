const std = @import("std");
const Logger = @import("debug/logger.zig").Logger;
const LogLevel = @import("debug/logger.zig").LogLevel;
const Cartridge = @import("core/cartridge.zig").Cartridge;
const Gameboy = @import("core/gameboy.zig").Gameboy;

pub fn main() !void {
    // init stdout writer
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    // init arena allocator
    const page_allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // init logger
    const logger = Logger.init(.{ .level = .debug });
    try logger.log(stdout, .debug, "Hello, World!");

    // get args
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();
    const first_arg = args.next();
    if (first_arg) |rom_path| {
        var cartridge = try Cartridge.init(allocator, rom_path);
        var gameboy = Gameboy.init();
        try logger.log(stdout, .debug, "Gameboy initialized!");

        gameboy.loadCartridge(&cartridge);
        try logger.log(stdout, .debug, "Cartridge has been loaded");

        // Main Loop
        while (true) {
            try gameboy.step();
        }
    } else {
        try stdout.print("Please provide a rom path as the first argument\n", .{});
        try stdout.flush();
    }
}
