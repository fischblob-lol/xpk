const std = @import("std");
const runner = @import("run.zig");

pub fn build(io: std.Io, allocator: std.mem.Allocator, args: ?[]const []const u8, source_dir: []const u8) !void {
    var configargv: std.ArrayList([]const u8) = .empty;
    try configargv.append(allocator, "./configure");
    
    if (args) |a| {
        for (a) |arg| try configargv.append(allocator, arg);
    }
    
    try runner.run_step(io, configargv.items, source_dir);
    try runner.run_step(io, &.{"make"}, source_dir);
}