const std = @import("std");
const runner = @import("run.zig");

// plain make almost never happens, but we gotta make it (im js copy and pasting the base structure and making it from there atp)
pub fn build(io: std.Io, allocator: std.mem.Allocator, args: ?[]const []const u8, sourced: []const u8) !void {
    var argv: std.ArrayList([]const u8) = .empty;
    
    try argv.append(allocator, "make");
    
    if (args) |a| {
        for (a) |arg| try argv.append(allocator, arg);
    }
    
    try runner.run_step(io, argv.items, sourced);
}