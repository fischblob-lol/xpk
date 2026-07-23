const std = @import("std");

// binary layout (index.bin, my v1):
//   name:  u16 (LE)   name bytes
//   cat:   u16 (LE)   category bytes
//   ver:   u16 (LE)   version bytes
//   desc:  u16 (LE)   description bytes
// fields are in this order, so they can be parsed (duh)
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
    // read_field, reads the field by getting position
    fn read_f(buf: []const u8, pos: *usize) []const u8 {
        const len = std.mem.readInt(u16, buf[pos.*..][0..2], .little);
        pos.* += 2;
        const s = buf[pos.*..][0..len];
        pos.* += len;
        return s;
    }
};