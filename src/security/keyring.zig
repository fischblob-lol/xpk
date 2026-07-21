const std = @import("std");
const types = @import("types/types.zig");
const print = std.debug.print;
 
inline fn errprint(comptime fmt: []const u8, args: anytype) void {
    print("[x] " ++ fmt, args);
}
 
inline fn iprint(comptime fmt: []const u8, args: anytype) void {
    print("[*] " ++ fmt, args);
}
 
inline fn wprint(comptime fmt: []const u8, args: anytype) void {
    print("[!] " ++ fmt, args);
}
 
 // IT IS 2:51 IN THE MORNING AND IM LOSING MY FUCKING MIND
// walks git manually to find head to find the head commit
pub fn resolve_headcom(io: std.Io, allocator: std.mem.Allocator, repopath: []const u8) ![]const u8 {
    const headpath = try std.fs.path.join(allocator, &.{ repopath, ".git", "HEAD" });
    defer allocator.free(headpath);
 
    const rawhead = try std.Io.Dir.cwd().readFileAlloc(io, headpath, allocator, .unlimited);
    defer allocator.free(rawhead);
    const head = std.mem.trim(u8, rawhead, " \n\r\t");
 
    if (!std.mem.startsWith(u8, head, "ref: ")) {
        // detached head
        return try allocator.dupe(u8, head);
    }
 
    const refname = std.mem.trim(u8, head[5..], " \n\r\t");
    const refpath = try std.fs.path.join(allocator, &.{ repopath, ".git", refname });
    defer allocator.free(refpath);
 
    const rawref = std.Io.Dir.cwd().readFileAlloc(io, refpath, allocator, .unlimited) catch |err| switch (err) {
        error.FileNotFound => return try resolve_pref(io, allocator, repopath, refname),
        else => return err,
    };
    defer allocator.free(rawref);
 
    return try allocator.dupe(u8, std.mem.trim(u8, rawref, " \n\r\t"));
}


// resolves git packed refs, idfk if it works but it should be able to check .git/packed-refs 
fn resolve_pref(io: std.Io, allocator: std.mem.Allocator, repopath: []const u8, refname: []const u8) ![]const u8 {
    const packedpath = try std.fs.path.join(allocator, &.{ repopath, ".git", "packed-refs" });
    defer allocator.free(packedpath);
 
    const rawpacked = try std.Io.Dir.cwd().readFileAlloc(io, packedpath, allocator, .unlimited);
    defer allocator.free(rawpacked);
 
    var lines = std.mem.splitScalar(u8, rawpacked, '\n');
    while (lines.next()) |line| {
        if (line.len == 0 or line[0] == '#' or line[0] == '^') continue;
        if (std.mem.endsWith(u8, line, refname)) {
            const space = std.mem.indexOfScalar(u8, line, ' ') orelse continue;
            return try allocator.dupe(u8, line[0..space]);
        }
    }
 
    return error.refnotfound;
}
