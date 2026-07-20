const std = @import("std");
const print = std.debug.print;

//global run command, ill use it in every single file to actually RUN the commands, its basically just a macro because i do not want to do std.process.spawn all the time
pub fn run_step(io: std.Io, argv: []const []const u8, cwdp: []const u8) !void {
    var child = try std.process.spawn(io, .{
        .argv = argv,
        .cwd = .{ .path = cwdp },
    });

    const term = try child.wait(io);
    switch (term) {
        .exited => |code| {
            if (code != 0) {
                print("command has failed with exit code {d}: {s}\n", .{ code, argv[0] });
                return error.buildstepfailed;
            }
        },
        .signal => |sig| {
            print("command killed by signal {d}: {s}\n", .{ @intFromEnum(sig), argv[0] }); // debug for sigs, can help diagnoize issues with running, but in normal running should never get killed by signal accept ctrl + c
            return error.buildstepfailed;
        },
        .stopped, .unknown => {
            print("command ended unexpectedly: {s}\n", .{argv[0]});
            return error.buildstepfailed;
        },
    }
}