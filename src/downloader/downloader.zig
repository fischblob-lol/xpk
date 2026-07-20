const std = @import("std");
const globals = @import("../globals.zig");
const print = std.debug.print;

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

// returns path to downloaded file
pub fn download(io: std.Io, allocator: std.mem.Allocator, url: []const u8) ![]const u8{
    const filename = std.fs.path.basename(url); // wow zig being beautiful

    // we return this, so no free
    const outputpath = try std.fs.path.join(allocator, &.{ globals.tmp, filename});
    errdefer allocator.free(outputpath);
   
    var client = std.http.Client{.allocator = allocator, .io = io};
    defer client.deinit();

    const uri = try std.Uri.parse(url);

    var req = try client.request(.GET, uri, .{});
    defer req.deinit();
   
    try req.sendBodiless();

    var redirectbuf: [1024]u8 = undefined; 
    var response = try req.receiveHead(&redirectbuf); // yeah man i recieve head too
    

    // straight from src/installer/downloader.zig
    var transferbuf: [4096]u8 = undefined; 
	var decompbuf: [65536]u8 = undefined; 
	var decomp: std.http.Decompress = undefined; 
	const reader = response.readerDecompressing(&transferbuf, &decomp, &decompbuf);
    

    const file = try std.Io.Dir.createFileAbsolute(
        io,
        outputpath,
        .{ .truncate = true},
    );
    defer file.close(io);

    // now unlike last time, we stream the data in so i can make the bar correspond to download, yay. 
    
    var writerbuf: [64 * 1024]u8 = undefined; // keep 64, benchmark 128 later

    var fwriter = file.writer(io, &writerbuf);
    const writer = &fwriter.interface; // ptr so we get live instance and we can pass const, this required 20 m of debugging. FUCK.

    var buf: [64 * 1024]u8 = undefined;
    var downloaded: usize = 0;
    var spinframe: u8 = 0;

    //streaming logic for bar, also added checks for how big the file is so it can adjust its decimal points from kib to mib, will add gb but only later for larger packages
    while (true) {
        const n = try reader.readSliceShort(&buf);
       
        if (n == 0) break;

        try writer.writeAll(buf[0..n]);

        downloaded += n;

        if (response.head.content_length) |total| {
            const width = 30;
            const filled = @min(downloaded * width / total, width);
            const percent = downloaded * 100 / total;

            print("\r[", .{});

            for (0..width) |i| {
                if (i < filled) {
                    print("#", .{});
                } else {
                    print(" ", .{});
                }
            }

            const downloadsize = @as(f64, @floatFromInt(downloaded));
            const totales = @as(f64, @floatFromInt(total));

            if (total < 1024 * 1024) {
                print("] {d}% {d:.1}/{d:.1} KiB", .{
                    percent,
                    downloadsize / 1024,
                    totales / 1024,
                });
            } else {
                print("] {d}% {d:.2}/{d:.2} MiB", .{
                    percent,
                    downloadsize / 1024 / 1024,
                    totales / 1024 / 1024,
                });
            }
        } else {
            // no content length here, so we just have a simple spinner so it looks alright anyways
            // so i need to figure out a way to not get this spinner for github
            spinframe +%= 1;
            const spinner = [_]u8{ '|', '/', '-', '\\' };
            const frame = spinner[spinframe % spinner.len];

            const downloadsize = @as(f64, @floatFromInt(downloaded));

            // same logic
            if (downloaded < 1024 * 1024) {
                print("\x1b[2K\r[{c}] downloading... {d:.1} KiB", .{ frame, downloadsize / 1024 });
            } else {
                print("\x1b[2K\r[{c}] downloading... {d:.2} MiB", .{ frame, downloadsize / 1024 / 1024 });
            }
        }
    }
    // newline because that one doesn't make one
    print("\n", .{});
    
    try writer.flush(); // flush because _______________
    return outputpath;
}

