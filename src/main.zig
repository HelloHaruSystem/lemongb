const std = @import("std");
const Logger = @import("debug/logger.zig").Logger;
const Cartridge = @import("core/cartridge.zig").Cartridge;
const Gameboy = @import("core/gameboy.zig").Gameboy;

pub fn main(init: std.process.Init) !void {
    // allocator setup
    const page_allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Io interface
    const io = init.io;

    // parse args
    var args = init.minimal.args.iterate();
    defer args.deinit();
    _ = args.skip();

    var rom_path: ?[]const u8 = null;
    var trace_enabled = false;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--trace")) {
            trace_enabled = true;
        } else {
            rom_path = arg;
        }
    }

    // stdout setup
    var write_buffer: [4096]u8 = undefined;
    var stdout_w = std.Io.File.stdout().writer(io, &write_buffer);
    const stdout = &stdout_w.interface;

    // logger
    const logger = Logger.init(.{ .level = .debug });

    // require rom path
    const path = rom_path orelse {
        try stdout.print("Usage: lemongb <rom> [--trace]\n", .{});
        try stdout.flush();
        return;
    };

    // setup trace writer if needed
    var trace_writer: ?*std.Io.Writer = null;
    var trace_w: std.Io.File.Writer = undefined;
    var trace_buffer: [128]u8 = undefined;
    if (trace_enabled) {
        try std.Io.Dir.cwd().createDirPath(io, "logs");
        const trace_file = try std.Io.Dir.cwd().createFile(io, "logs/trace", .{ .truncate = true });
        trace_w = trace_file.writer(io, &trace_buffer);
        trace_writer = &trace_w.interface;
    }

    // init and run
    var cartridge = try Cartridge.init(allocator, io, path);
    var gameboy = Gameboy.init();
    try logger.log(stdout, .debug, "Gameboy initialized!");

    gameboy.loadCartridge(&cartridge);
    try logger.log(stdout, .debug, "Cartridge loaded!");

    while (true) {
        try gameboy.step(trace_writer);
    }
}
