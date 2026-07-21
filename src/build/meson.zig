const std = @import("std");
const runner = @import("run.zig");

pub fn build(io: std.Io, allocator: std.mem.Allocator, args: ?[][]const u8, sourced: []const u8) !void {
    var configargvs: std.ArrayList([]const u8) = .empty;
    try configargvs.append(allocator, "meson");

    try configargvs.append(allocator, "setup");
    
    try configargvs.append(allocator, "build");

    if (args) |a| {
        for (a) |arg| try configargvs.append(allocator, arg);
    }
    try runner.run_step(io, configargvs.items, sourced);
    try runner.run_step(io, &.{ "meson", "compile", "-C", "build" }, sourced);
}