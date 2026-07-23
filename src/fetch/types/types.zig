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

    // encodes this entry as its binary blob (see layout above)
    pub fn encode(self: Idxentry, allocator: std.mem.Allocator) ![]u8 {
        var blob: std.ArrayList(u8) = .empty;
        errdefer blob.deinit(allocator);

        inline for (.{ self.name, self.category, self.version, self.description }) |field| {
            var lenbuf: [2]u8 = undefined;
            std.mem.writeInt(u16, &lenbuf, @intCast(field.len), .little);
            try blob.appendSlice(allocator, &lenbuf);
            try blob.appendSlice(allocator, field);
        }

        return blob.toOwnedSlice(allocator);
    }

   
    // decodes an entry starting a offs in buf, without copy, the returned slices borrow directly from buf so buf must 100% outlive idxentry
    pub fn decode(buf: []const u8, offset: usize) Idxentry {
        var pos = offset;

        const name = read_f(buf, &pos);
        const category = read_f(buf, &pos);
        const version = read_f(buf, &pos);
        const description = read_f(buf, &pos);

        return .{
            .name = name,
            .category = category,
            .version = version,
            .description = description,
        };
    }
    // reads the field
    fn read_f(buf: []const u8, pos: *usize) []const u8 {
        const len = std.mem.readInt(u16, buf[pos.*..][0..2], .little);
        pos.* += 2;
        const s = buf[pos.*..][0..len];
        pos.* += len;
        return s;
    }
};

pub const Indexerror = error{ badmagic, unsupportedvers, crcmismatch, truncated };

const Parsedidx = struct {
    offsets: []u32,
    entriesst: usize,
};

// walks the header, validates magic/version/crc, hands back the offset table, god i fucking love tables, just tables all over sql shit ykkkkk
pub fn parse_idx(buf: []const u8, allocator: std.mem.Allocator) !Parsedidx {
    if (buf.len < 10 + 4) return Indexerror.truncated; // header + at least the crc

    if (!std.mem.eql(u8, buf[0..4], "XPKI")) return Indexerror.badmagic;

    var pos: usize = 4;
    const version = std.mem.readInt(u16, buf[pos..][0..2], .little);
    pos += 2;
    if (version != 1) return Indexerror.unsupportedvers;

    const count = std.mem.readInt(u32, buf[pos..][0..4], .little);
    pos += 4;

    const offsets = try allocator.alloc(u32, count);
    errdefer allocator.free(offsets);
    for (offsets) |*o| {
        o.* = std.mem.readInt(u32, buf[pos..][0..4], .little);
        pos += 4;
    }

    const entriesst = pos;

    const storedcrc = std.mem.readInt(u32, buf[buf.len - 4 ..][0..4], .little);
    const expectedcrc = std.hash.Crc32.hash(buf[0 .. buf.len - 4]);
    if (storedcrc != expectedcrc) return Indexerror.crcmismatch;

    return .{ .offsets = offsets, .entriesst = entriesst };
}

// binary search over the sorted offset table 
pub fn find_package(buf: []const u8, offsets: []const u32, entriesst: usize, name: []const u8) ?Idxentry {
    var lo: usize = 0;
    var hi: usize = offsets.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const entry = Idxentry.decode(buf, entriesst + offsets[mid]);
        switch (std.mem.order(u8, entry.name, name)) {
            .eq => return entry,
            .lt => lo = mid + 1,
            .gt => hi = mid,
        }
    }
    return null;
}
