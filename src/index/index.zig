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


// indexes a repo from a path and recursively generates a idxentry per package, also has someee debug output but ill prob wire up alot more 
// will rewrite for own binary custom format when more then 200 packages cumulate, so the index file is easier to handle
// this is more of a developer exclusive use tool, as its made for generating repos instead of updating
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

            // appends everything so it can put it into a json format, unrolled for readability 
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

    // here that happens
    const indexjson = try std.json.Stringify.valueAlloc(allocator, entries.items,.{.whitespace = .indent_2}); // indent_2 cuz easy to read
    defer allocator.free(indexjson);

    const idxjson = try std.fmt.allocPrint(allocator, "{s}/index.json", .{repopath});
    defer allocator.free(idxjson);

    // final things + write stuff
    const indexfile = try std.Io.Dir.createFileAbsolute(io, idxjson, .{ .truncate = true });
    defer indexfile.close(io);

    var writerbuf: [16 * 1024]u8 = undefined;
    var writer = indexfile.writer(io, &writerbuf);

    try writer.interface.writeAll(indexjson);
    try writer.interface.flush();

    iprint("indexed {d} packages\n", .{entries.items.len});
}