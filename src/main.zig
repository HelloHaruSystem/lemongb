const std = @import("std");

pub fn main() !void {
    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const page_allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();
    const first_arg = args.next();
    if (first_arg) |arg| {
        try stdout.print("Hello, {s}!\n", .{arg});
    } else {
        try stdout.print("Hello!\n", .{});
    }

    try stdout.flush();
}
