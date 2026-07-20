const std = @import("std");

pub const Pkgurl = struct {
    allocator: std.mem.Allocator, 
    xbuild: ?[]const u8,

    pub fn deinit(self: *Pkgurl) void {
        if (self.xbuild) |m| self.allocator.free(m);
        self.xbuild = null;
    }
};

// readded, because i put whatever i want to use in types/types.zig, and it doesnt contact with 'index' (atleast not yet) so im not putting it in utils
pub const Idxentry = struct {
    name: []const u8,
    category: []const u8,
    version: []const u8,
    description: []const u8,
};

