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

inline fn errprint(comptime fmt: []const u8, args: anytype) void {
    print("[x] " ++ fmt, args);
}

inline fn iprint(comptime fmt: []const u8, args: anytype) void {
    print("[*] " ++ fmt, args);
}

inline fn wprint(comptime fmt: []const u8, args: anytype) void {
    print("[!] " ++ fmt, args);
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
pub fn pull_repo(io: std.Io, allocator: std.mem.Allocator) !void {

    const reposbytes = try std.Io.Dir.cwd().readFileAlloc(io,globals.reposconf, allocator, .unlimited);
    defer allocator.free(reposbytes);


    const repos = try utils.parser.parse_r(allocator,reposbytes);
    defer allocator.free(repos);


    for (repos) |repo| {
        if (!repo.enabled){
            continue;
        }
        

        // globals are gonna make it much easier to port to linux later
        const repopath = try std.fs.path.join(allocator,&.{globals.local, repo.name});
        defer allocator.free(repopath);


        try createdir(io,repopath);


        const indexurl = try std.fmt.allocPrint(
            allocator,
            "{s}/index.json",
            .{repo.url},
        );
        // 
        const keyringurl = try std.fmt.allocPrint(
            allocator,
            "{s}/trust/keyring.json",
            .{repo.url}
        );

    
        defer allocator.free(indexurl);
        defer allocator.free(keyringurl);


        iprint("syncing {s}\n",.{repo.name});

        // NO ASYNC YET ADD ASYNC LATER!!!
        // NO ASYNC YET ADD ASYNC LATER!!!
        // NO ASYNC YET ADD ASYNC LATER!!!
        // NO ASYNC YET ADD ASYNC LATER!!!
        // NO ASYNC YET ADD ASYNC LATER!!!
        // aka tmrw
        const downloadedindex = try downloader.download(io,allocator, indexurl, false);
        const downloadedkeyring = try downloader.download(io, allocator, keyringurl, true);

        const indexpath = try std.fs.path.join(allocator, &.{repopath, "index.json"});
        const keyringpath = try std.fs.path.join(allocator, &.{repopath, "keyring.json"});
        
        defer allocator.free(indexpath);
        defer allocator.free(keyringpath);

        const old = std.Io.Dir.openFileAbsolute(io, indexpath,.{}) catch null;
        const old2 = std.Io.Dir.openFileAbsolute(io, keyringpath,.{}) catch null; // catches null instead of try so we dont get error that fucks sync up

        if (old) |file| {
            file.close(io);
            try std.Io.Dir.deleteFileAbsolute(io,indexpath);
        }

        if (old2) |file| {
            file.close(io);
            try std.Io.Dir.deleteFileAbsolute(io,keyringpath);
        }
        
        // renames the index.json into the indexpath, clever little trick to just move file into another location, which is name of repo in /opt/xpk/repos + index.json, simple
        try std.Io.Dir.renameAbsolute(downloadedindex,indexpath,io);
        try std.Io.Dir.renameAbsolute(downloadedkeyring,keyringpath,io);


        iprint("repository {s} updated\n",.{repo.name});
    }
}