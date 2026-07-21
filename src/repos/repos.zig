const std = @import("std");
const types = @import("types/types.zig");
const print = std.debug.print;

fn strip_comment(line: []const u8) []const u8 {
    var quoted = false;
    for (line, 0..) | c, i | {
        if (c == '"') quoted = !quoted;
        if (c == '#' and !quoted) return std.mem.trim(u8, line[0..i], " \t\r");
    }
    return std.mem.trim(u8, line, " \t\r");
} 

fn parse_quoted(value: []const u8) []const u8 {
    const trimmed = std.mem.trim(u8, value, " \t");
    if (trimmed.len >= 2 and trimmed[0] == '"' and trimmed[trimmed.len - 1] == '"') {
        return trimmed[1 .. trimmed.len - 1];
    }
    return trimmed;
}

inline fn errprint(comptime fmt: []const u8, args: anytype) void {
    print("[x] " ++ fmt, args);
}

//parse_repos, most code is taken from parser.zig from parse_i because i developed it first, just diff format
// this will also get reworked, because we are gonna switch from codeberg to static hosting websites for speed
pub fn parse_r(allocator: std.mem.Allocator, text: []const u8) ![]types.Repo {
    var repos: std.ArrayList(types.Repo) = .empty;
    errdefer repos.deinit(allocator);

    var current: types.Repo = .{};
    var hasrepo = false;

    var lines = std.mem.splitScalar(u8, text, '\n');

    while (lines.next()) |rawline| {
        const line = strip_comment(rawline);

        if (line.len == 0)
            continue;

        // section
        if (line[0] == '[' and line[line.len - 1] == ']') {
            if (hasrepo) {
                try repos.append(allocator, current);
            }

            current = .{};
            current.name = line[1 .. line.len - 1];
            hasrepo = true;
            continue;
        }

        if (!hasrepo)
            continue;

        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;

        const key = std.mem.trim(u8, line[0..eq], " \t");
        const value = parse_quoted(line[eq + 1 ..]);

        if (std.mem.eql(u8, key, "url")) { 
            if (std.mem.indexOf(u8, value, "codeberg") != null) {
            // for codeberg or foirjo i forgot the name
                current.url = try std.fmt.allocPrint(
                    allocator,
                    "{s}/raw",
                    .{value},
                );
                } else if (std.mem.indexOf(u8, value, "github") != null) {
                // for github
                    current.url = try std.fmt.allocPrint(
                    allocator,
                    "{s}/raw/main",
                    .{value},
                );
                } else {
                // case of unknown host, will work if the layout is cool but ill add more checks n shit
                current.url = try allocator.dupe(u8, value);
            }  
        } else if (std.mem.eql(u8, key, "priority")) {
            current.priority = try std.fmt.parseInt(u8, value, 10);
        } else if (std.mem.eql(u8, key, "enabled")) {
            if (std.mem.eql(u8, value, "true")) {
                current.enabled = true;
            } else if (std.mem.eql(u8, value, "false")) {
                current.enabled = false;
            } else {
                return error.invalidbool;
            }
        }
    }

    if (hasrepo) {
        try repos.append(allocator, current);
    }

    if (repos.items.len == 0) {
        return error.norepospleasereaddcore; // technichally will not happen under normal circumstances as xpk auto creates core repo on first use, but if you rm the file its a helpful debugger
    }

    return repos.toOwnedSlice(allocator);
}