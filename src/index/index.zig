const std = @import("std");
const utils = @import("../utils/utils.zig");
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

// magic bytes for index.bin, so you can instantly tell from a xxd/hexdump, and because it looks fucking awesome and cool tbh
const MAGIC = "XPKI";
const FORMATVERS: u16 = 1;

// i need these guys, since we are actually writing hex now
inline fn writeU16(list: *std.ArrayList(u8), allocator: std.mem.Allocator, val: u16) !void {
    var buf: [2]u8 = undefined;
    std.mem.writeInt(u16, &buf, val, .little);
    try list.appendSlice(allocator, &buf);
}

inline fn writeU32(list: *std.ArrayList(u8), allocator: std.mem.Allocator, val: u32) !void {
    var buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &buf, val, .little);
    try list.appendSlice(allocator, &buf);
}

// encodes the whole entry list into the index.bin 
//   "XPKI" | version u16 | count u32 | offsets[count] u32 (sorted by name) | entries... | crc32 u32
fn encode_idx(allocator: std.mem.Allocator, entries: []types.Idxentry) ![]u8 {
    std.mem.sort(types.Idxentry, entries, {}, struct {
        fn lessThan(_: void, a: types.Idxentry, b: types.Idxentry) bool {
            return std.mem.order(u8, a.name, b.name) == .lt;
        }
    }.lessThan);

    // encode entries standalone first so we know each blob's length for the offset table
    var entriesblob: std.ArrayList([]u8) = .empty;
    defer {
        for (entriesblob.items) |blob| allocator.free(blob);
        entriesblob.deinit(allocator);
    }

    for (entries) |entry| {
        const blob = try entry.encode(allocator);
        try entriesblob.append(allocator, blob);
    }

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    try out.appendSlice(allocator, MAGIC);
    try writeU16(&out, allocator, FORMATVERS);
    try writeU32(&out, allocator, @intCast(entries.len));

    // offset table -- running total of prior entry blob lengths
    var roffs: u32 = 0;
    for (entriesblob.items) |blob| {
        try writeU32(&out, allocator, roffs);
        roffs += @intCast(blob.len);
    }

    for (entriesblob.items) |blob| {
        try out.appendSlice(allocator, blob);
    }

    // crc32 over everything written so far, because resolvers can tell this one, and its pretty unique??? 
    const crc = std.hash.Crc32.hash(out.items);
    try writeU32(&out, allocator, crc);

    return out.toOwnedSlice(allocator);
}

// indexes a repo from a path and recursively generates a idxentry per package, also has someee debug output but ill prob wire up alot more 
// now writes its own binary format (index.bin) instead of json
// this is more of a developer exclusive use tool, as its made for generating repos instead of updating, however users can obviously just use this tool to wire up their own repos
pub fn index_repo(io: std.Io, allocator: std.mem.Allocator, repopath: []const u8) !void {
    var entries: std.ArrayList(types.Idxentry) = .empty;
    defer entries.deinit(allocator);

    var dir = try std.Io.Dir.openDirAbsolute(io, repopath, .{ .iterate = true });
    defer dir.close(io);

    var categories = dir.iterate();

    while (try categories.next(io)) |category| {
        if (category.kind != .directory) continue;
        if (category.name.len > 0 and category.name[0] == '.') continue; // skip .git, .github, any dotfiles because they arent meant to contain anything, this broke indexing especially after fecthing packages from repo and tryna index and add

        const categorypath = try std.fs.path.join(allocator, &.{ repopath, category.name });
        defer allocator.free(categorypath);

        var catdir = try std.Io.Dir.openDirAbsolute(io, categorypath, .{ .iterate = true });
        defer catdir.close(io);

        var packages = catdir.iterate();

        while (try packages.next(io)) |package| {
            if (package.kind != .directory) continue;
            if (package.name.len > 0 and package.name[0] == '.') continue; // same guard as mentioned before

            const buildpath = try std.fs.path.join(allocator, &.{ categorypath, package.name, "xbuild" });
            defer allocator.free(buildpath);

            const bytes = std.Io.Dir.cwd().readFileAlloc(io, buildpath, allocator, .unlimited) catch |err| switch (err) {
                error.FileNotFound => {
                    wprint("{s}/{s} has no xbuild, skipping\n", .{ category.name, package.name });
                    continue;
                }, else => return err,
            };
            defer allocator.free(bytes);       
            
            // this will fail if not all requirements for [pkg] and [build] are satisfied too, however i think thats fine for right now or maybe long term before we get 'just' binaries 
            const xbuild = try utils.parser.parse_a(allocator, bytes);
    
            // desc is optional in the type, but the index wants a string for every entry.
            // rather than force unwrap and panic the whole index run over one sloppy package, it just empties it and warns so you actually write a desc
            const desc = xbuild.info.desc orelse blk: {
                wprint("{s}/{s} has no desc in xbuild, defaulting to nothin\n", .{ category.name, package.name },);
                break :blk ""; // break loop, i hate that syntax 
            };

            // appends everything so it can put it into the binary blob, unrolled for readability 
            try entries.append(allocator, .{
                .name = try allocator.dupe(u8, xbuild.info.name),
                .category = try allocator.dupe(u8, category.name),
                .version = try allocator.dupe(u8, xbuild.info.version),
                .description = try allocator.dupe(u8, desc),
            });

            // nice to just do this
            iprint("{s}/{s} indexed\n", .{ category.name, package.name });
        }
    }

    // here that happens, we encode the blob
    const indexbin = try encode_idx(allocator, entries.items);
    defer allocator.free(indexbin);

    const idxbin = try std.fmt.allocPrint(allocator, "{s}/index.bin", .{repopath});
    defer allocator.free(idxbin);

    // final things + write stuff
    const indexfile = try std.Io.Dir.createFileAbsolute(io, idxbin, .{ .truncate = true });
    defer indexfile.close(io);

    var writerbuf: [16 * 1024]u8 = undefined;
    var writer = indexfile.writer(io, &writerbuf);

    try writer.interface.writeAll(indexbin);
    try writer.interface.flush();

    iprint("indexed {d} packages\n", .{entries.items.len});
}