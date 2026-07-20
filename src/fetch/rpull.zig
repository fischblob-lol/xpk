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
    
    print("first run of xpk may be quite slow due to initalization!\n", .{});

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
        defer allocator.free(indexurl);


        print("syncing {s}\n",.{repo.name});


        const downloaded = try downloader.download(io,allocator, indexurl);

        const indexpath = try std.fs.path.join(allocator, &.{repopath, "index.json"});
        defer allocator.free(indexpath);

        const old = std.Io.Dir.openFileAbsolute(io, indexpath,.{}) catch null; // catches null instead of try so we dont get error that fucks sync up

        if (old) |file| {
            file.close(io);
            try std.Io.Dir.deleteFileAbsolute(io,indexpath);
        }

        // renames the index.json into the indexpath, clever little trick to just move file into another location, which is name of repo in /opt/xpk/repos + index.json, simple
        try std.Io.Dir.renameAbsolute(downloaded,indexpath,io);


        print("repository {s} updated\n",.{repo.name});
    }
}