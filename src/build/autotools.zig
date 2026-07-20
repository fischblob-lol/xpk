const std = @import("std");
const runner = @import("run.zig");

pub fn build(io: std.Io, allocator: std.mem.Allocator, args: ?[][]const u8, source_dir: []const u8) !void {
    var configure_argv: std.ArrayList([]const u8) = .empty;
    try configure_argv.append(allocator, "./configure");
    if (args) |a| {
        for (a) |arg| try configure_argv.append(allocator, arg);
    }
    try runner.run_step(io, configure_argv.items, source_dir);
    try runner.run_step(io, &.{"make"}, source_dir);
}