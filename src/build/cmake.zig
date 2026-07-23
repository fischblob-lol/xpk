const std = @import("std");
const runner = @import("run.zig");

pub fn build(io: std.Io, allocator: std.mem.Allocator, args: ?[]const []const u8, sourced: []const u8) !void {
    var argv: std.ArrayList([]const u8) = .empty;
    
    try argv.append(allocator, "cmake");
    try argv.append(allocator, ".");
    
    if (args) |a| {
        for (a) |arg| try argv.append(allocator, arg);
    }
    
    try runner.run_step(io, argv.items, sourced);
    try runner.run_step(io, &.{"make"}, sourced);
}