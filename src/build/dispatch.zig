const std = @import("std");
const runner = @import("run.zig");
const cmake = @import("cmake.zig");
const make = @import("make.zig");
const meson = @import("meson.zig");
const utils = @import("../utils/utils.zig");
const autotools = @import("autotools.zig");


// actually runs the shit, has to spawn child shells unfortunately, but its fine
pub fn run_build(io: std.Io, allocator: std.mem.Allocator, build: utils.parser.Build, pkg: utils.parser.Pkg, sourced: []const u8) !void {
    // also BAD `
    if (pkg.pre_hooks) |hooks| {
        for (hooks) |hook| try runner.run_step(io, &.{ "sh", "-c", hook }, sourced);
    }

    // i could make an enum so it will be easier to read but its the least of my concerns currently
    if (std.mem.eql(u8, build.build_sys, "cmake")) {
        try cmake.build(io, allocator, build.args, sourced);
    } else if (std.mem.eql(u8, build.build_sys, "make")) {
        try make.build(io, allocator, build.args, sourced);
    } else if (std.mem.eql(u8, build.build_sys, "meson")) {
        try meson.build(io, allocator, build.args, sourced);
    } else if (std.mem.eql(u8, build.build_sys, "autotools")){
        try autotools.build(io, allocator, build.args, sourced);
    } else {
        std.debug.print("unsupported build system: {s}\n", .{build.build_sys});
        return error.unsupportedbuildsystem; // keep error here instead of std.process.exit to showcase this is bad and the spec sheet needs rework
    }
    // just as bad
    if (build.script) |script| {
        try runner.run_step(io, &.{ "sh", "-c", script }, sourced);
    }
    // BAD! BAD! BAD! i will remake this, has full perms under root so it can essentially rm -rf your home, or root if SIP is off on mac
    if (build.post_hooks) |hooks| {
        for (hooks) |hook| try runner.run_step(io, &.{ "sh", "-c", hook }, sourced);
    }
}