//! rework
//! remote fetch now assumes index is local, helps with speeds a lot because we split downloads on repos
//! switched index.json to index.bin, own format now. yay.
//! yeah.

const std = @import("std");
const types = @import("types/types.zig");
const globals = @import("../globals.zig");
const downloader = @import("../downloader/downloader.zig");
const utils = @import("../utils/utils.zig");

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

// taken from neo, only thing implemented new is the limit, so malicious gigantic package specs/infos cant lag you (unless you are lacking 8192 bytes of ram)
fn fetchraw(allocator: std.mem.Allocator, io: std.Io, url: []const u8) ![]u8 {
    var client = std.http.Client{ .allocator = allocator, .io = io };
    defer client.deinit();

    const uri = try std.Uri.parse(url);
    var req = try client.request(.GET, uri, .{});
    defer req.deinit();
    try req.sendBodiless();

    var redirectbuf: [1024]u8 = undefined;
    var response = try req.receiveHead(&redirectbuf);

    var transferbuf: [4096]u8 = undefined;
    var decompbuf: [65536]u8 = undefined;
    var decomp: std.http.Decompress = undefined;
    const reader = response.readerDecompressing(&transferbuf, &decomp, &decompbuf);

    return try reader.allocRemaining(allocator, .limited(8192));
}

// checks your index.bin's from each repo
pub fn remote_fetch(io: std.Io, allocator: std.mem.Allocator, package: []const u8) !types.Pkgurl {
    const reposbytes = try std.Io.Dir.cwd().readFileAlloc(io, globals.reposconf, allocator, .unlimited);
    defer allocator.free(reposbytes);

    const repos = try utils.parser.parse_r(allocator, reposbytes);
    defer allocator.free(repos);

    var foundrepo: ?utils.parser.Repo = null;
    var foundpkg: ?types.Idxentry = null;

    for (repos) |repo| {
        if (!repo.enabled) continue;

        const indexpath = try std.fs.path.join(allocator, &.{ globals.local, repo.name, "index.bin" });
        defer allocator.free(indexpath);

        // we dont free here for a REASON its in a FOR LOOP
        const indexbytes = std.Io.Dir.cwd().readFileAlloc(io, indexpath, allocator, .unlimited) catch continue;

        // also can notice malformed ones if it fails, so its a really nice change really
        const parsed = types.parse_idx(indexbytes, allocator) catch |err| {
            wprint("{s}'s index.bin is malformed ({s}), skipping repo\n", .{ repo.name, @errorName(err) });
            continue;
        };
        defer allocator.free(parsed.offsets); // we free these cuz we don't need allat
        // uses the parsed offset table and find_package to find the package
        if (types.find_package(indexbytes, parsed.offsets, parsed.entriesst, package)) |entry| {
            foundrepo = repo;
            foundpkg = entry;
            break;
        }
    }

    const repo = foundrepo orelse {
        wprint("package {s} doesn't exist in any enabled repo\n", .{package});
        std.process.exit(1);
    };

    const pkg = foundpkg orelse {
        wprint("package {s} doesn't exist in any enabled repo\n", .{package});
        std.process.exit(1); // errors that happen a lot are ugly, thats why std.process.exit is used to not let that happen
    };

    const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ pkg.category, pkg.name });
    defer allocator.free(path);

    // one call now, way more efficent
    const xbuildurl = try std.fmt.allocPrint(allocator, "{s}/{s}/xbuild", .{ repo.url, path });
    defer allocator.free(xbuildurl);

    iprint("getting remote build files...\n", .{});

    const xbuildbytes = try fetchraw(allocator, io, xbuildurl);

    return types.Pkgurl{ .allocator = allocator, .xbuild = xbuildbytes };
}