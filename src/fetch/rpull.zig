const std = @import("std");
const globals = @import("../globals.zig");
const downloader = @import("../downloader/downloader.zig");
const utils = @import("../utils/utils.zig");
const print = std.debug.print;

// made a function for creating dirs, so if it stalls it only errors the function and not errors pull_repo, messy workaround but wtv
fn createdir(io: std.Io, path: []const u8) !void {
    std.Io.Dir.createDirAbsolute(
        io,
        path,
        .default_dir,
    ) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}
// and another one here, because iof the crossdevice bug
fn rename(io: std.Io, old: []const u8, new: []const u8) !void {
    std.Io.Dir.renameAbsolute(old, new, io) catch |err| switch (err) {
        error.CrossDevice => {
            // rename cannot cross filesystems, so we just stream and delete, also atomic so its better realistically

            const src = try std.Io.Dir.openFileAbsolute(io, old, .{});
            defer src.close(io);

            const dst = try std.Io.Dir.createFileAbsolute(io, new, .{
                .truncate = true,
            });
            defer dst.close(io);

            var writerbuf: [64 * 1024]u8 = undefined;
            var fwriter = dst.writer(io, &writerbuf);
            const writer = &fwriter.interface;

            var buf: [64 * 1024]u8 = undefined;
            var freader = src.reader(io, &buf);
            const reader = &freader.interface;

            while (true) {
                const n = try reader.readSliceShort(&buf);
                

                if (n == 0)
                    break;

                try writer.writeAll(buf[0..n]);
            }
    
            try writer.flush();

            try std.Io.Dir.deleteFileAbsolute(io, old);
        },
        else => return err,
    };
}


inline fn errprint(comptime fmt: []const u8, args: anytype) void {
    print("[x] " ++ fmt, args);
}

inline fn iprint(comptime fmt: []const u8, args: anytype) void {
    print("[*] " ++ fmt, args);
}

inline fn wprint(comptime fmt: []const u8, args: anytype) void {
    print("[!] " ++ fmt, args);
}

// cool looking print
inline fn cprint(comptime fmt: []const u8, args: anytype) void {
    print("[+] " ++ fmt, args);
}


// inits the main repo firstly, used in main right after all creations run, this is gonna uhh change, 100% because this is the commit to github
pub fn init_repos(io: std.Io) !void {
    const contents =
        \\[core]
        \\url = "https://github.com/fischblob-lol/xpk-c"
        \\priority = 100
        \\enabled = true
        \\# hello from sundowner (expie)
        \\
    ;
    
    wprint("first run of xpk may be quite slow due to initalization!\n", .{});

    if (std.Io.Dir.openFileAbsolute(io, globals.reposconf, .{ .mode = .read_only })) |file| {
        file.close(io);
        return;
    } else |err| if (err != error.FileNotFound) return err;

    const file = try std.Io.Dir.createFileAbsolute(io, globals.reposconf, .{ .truncate = false });
    defer file.close(io);

    var writerbuf: [64 * 1024]u8 = undefined;
    
    var fwriter = file.writer(io, &writerbuf);
    const writer = &fwriter.interface;
    
    try writer.writeAll(contents);
    try writer.flush(); 
}

// saves locally, for the repo name inscribed in /opt/xpk/repos/repos.conf (parser work)
// concurrently, and this is just the old renamed torso for pull_repos, this gets a repo handed to it, and downloads it
fn sync_repo(io: std.Io, allocator: std.mem.Allocator, repo: utils.parser.Repo) !void {
    // globals are gonna make it much easier to port to linux later
    const repopath = try std.fs.path.join(allocator, &.{ globals.local, repo.name });
    defer allocator.free(repopath);

    try createdir(io, repopath); // safe because if error it just catches null and exits only this not main problem

    const indexurl = try std.fmt.allocPrint(
        allocator,
        "{s}/index.bin",
        .{repo.url},
    );
    // urls forming
    const keyringurl = try std.fmt.allocPrint(
        allocator,
        "{s}/trust/keyring.autm",
        .{repo.url},
    );

    defer allocator.free(indexurl);
    defer allocator.free(keyringurl);

    // async time bitchh also download_repo now grows for async
    var indexfut = io.async(downloader.download_repo, .{ io, allocator, indexurl, repo.name, false });
    var keyringfut = io.async(downloader.download, .{ io, allocator, keyringurl, true });

    const downloadedindex = try indexfut.await(io);
    const downloadedkeyring = try keyringfut.await(io);

    const indexpath = try std.fs.path.join(allocator, &.{ repopath, "index.bin" });
    const keyringpath = try std.fs.path.join(allocator, &.{ repopath, "keyring.autm" });
    defer allocator.free(indexpath);
    defer allocator.free(keyringpath);
    // renames the index.bin into the indexpath, clever little trick to just move file into another location, which is name of repo in /opt/xpk/repos + index.bin, simple
    try rename(io, downloadedindex, indexpath);
    try rename(io, downloadedkeyring, keyringpath);
}

// pulls repos and uses async
pub fn pull_repo(io: std.Io, allocator: std.mem.Allocator) !void {
    const reposbytes = try std.Io.Dir.cwd().readFileAlloc(io, globals.reposconf, allocator, .unlimited);
    defer allocator.free(reposbytes);

    cprint("syncing repos...\n", .{});

    const repos = try utils.parser.parse_r(allocator, reposbytes);
    defer allocator.free(repos);
    
    if (repos.len == 0) {
        iprint("no repositories configured\n", .{});
        return;
    }

    const Fut = @TypeOf(io.async(sync_repo, .{ io, allocator, repos[0] }));
    var futures: std.ArrayList(Fut) = .empty;
    defer futures.deinit(allocator);

    // keep repo names lined up with futures so we can report which one failed
    var names: std.ArrayList([]const u8) = .empty;
    defer names.deinit(allocator);

    for (repos) |repo| {
        if (!repo.enabled) continue;
        try futures.append(allocator, io.async(sync_repo, .{ io, allocator, repo }));
        try names.append(allocator, repo.name);
    }

    var failures: usize = 0;

    for (futures.items, 0..) |*futs, i| {
        futs.await(io) catch |err| {
            wprint("failed to sync {s}: {s}, skipping\n", .{ names.items[i], @errorName(err) });
            failures += 1;
            continue;
        };
    }
    // usually all repos failed to sync means your internet isnt fucking working
    if (failures == futures.items.len and futures.items.len > 0) {
        errprint("all repositories failed to sync, are you sure you are online?\n", .{});
    } else {
        iprint("all repositories up to date!\n", .{});
    }
}

