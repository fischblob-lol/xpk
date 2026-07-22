const std = @import("std");
const types = @import("types/types.zig");
const stripl = @import("stripl.zig");
const print = std.debug.print;

const strip_comment = stripl.strip_comment;
const parse_quoted = stripl.parse_quoted;

inline fn errprint(comptime fmt: []const u8, args: anytype) void {
    print("[x] " ++ fmt, args);
}
 
inline fn iprint(comptime fmt: []const u8, args: anytype) void {
    print("[*] " ++ fmt, args);
}
 
inline fn wprint(comptime fmt: []const u8, args: anytype) void {
    print("[!] " ++ fmt, args);
}
 
// parse_keyring, basically the only big difference is using hashmaps because of how it sorts [headers], im pretty new to hashmaps so i have no idea if this is good usage
pub fn parse_k(allocator: std.mem.Allocator, text: []const u8) !types.Keyring {
    var result: types.Keyring = .{
        .maintainers = std.StringHashMap(types.Key).init(allocator),
        .helpers = std.StringHashMap(types.Key).init(allocator),
    };

    // since there are many sections i have finally decided to put them in an enum, will do same for big parser
    var section: enum { none, hash, maintainers, helpers, policy } = .none;
    var currentid: []const u8 = "";
    var current: types.Key = .{}; // only real mfs from WOF: beta rp know, CURRENTLY hahah im funny right inside joke

    var foundkeys = false;

    var lines = std.mem.splitScalar(u8, text, '\n');

    while (lines.next()) |rawline| {
        const line = strip_comment(rawline);
        if (line.len == 0) continue;


        // section header
        if (line[0] == '[' and line[line.len - 1] == ']') {

            // save old key before changing
            if (currentid.len > 0) {
                switch (section) {
                    .maintainers => try result.maintainers.put(currentid, current),
                    .helpers => try result.helpers.put(currentid, current),
                    .none, .hash, .policy => {},
                }
            }

            current = .{};
            currentid = "";

            const name = line[1 .. line.len - 1];

            var parts = std.mem.splitScalar(u8, name, '.');

            const root = parts.next() orelse "";
            const id = parts.next() orelse "";

            if (std.mem.eql(u8, root, "maintainers")) {
                section = .maintainers;
                currentid = id;
            } else if (std.mem.eql(u8, root, "helpers")) {
                section = .helpers;
                currentid = id;
            } else if (std.mem.eql(u8, root, "hash")) {
                section = .hash;
            } else if (std.mem.eql(u8, root, "policy")) {
                section = .policy;
            } else {
                return error.badkeysection;
            }

            foundkeys = true;

            continue;
        }


        if (section == .none)
            continue;

        // same ass idx logic that i do every single time
        const eqidx = std.mem.indexOfScalar(u8, line, '=') orelse continue;

        const key = std.mem.trim(u8, line[0..eqidx], " \t");
        var value = std.mem.trim(u8, line[eqidx + 1 ..], " \t");

        value = parse_quoted(value);


        // same thing i have in ALL my awtoml parsers

        switch (section) {
            .maintainers, .helpers => {
                if (std.mem.eql(u8, key, "fingerprint")) {
                    current.fingerprint = value;
                } else if (std.mem.eql(u8, key, "added")) { // added should be a precise timestamp of d/m/y h:m 
                    current.added = value;
                } else if (std.mem.eql(u8, key, "active")) {
                    current.active = std.mem.eql(u8, value, "true");
                } else if (std.mem.eql(u8, key, "revoked")) {
                    current.revoked = std.mem.eql(u8, value, "true");
                } else {
                    return error.unknownkeyinkeyring;
                }
            },
            .hash => {
                if (std.mem.eql(u8, key, "head")) {
                    result.head = value;
                } else if (std.mem.eql(u8, key, "last-edit")) {
                    result.hashlastedit = value;
                } else {
                    return error.unknownkeyinhash;
                }
            },
            .policy => {
                if (std.mem.eql(u8, key, "required-signatures")) {
                    result.requiredsigs = try std.fmt.parseInt(u32, value, 10);
                } else if (std.mem.eql(u8, key, "allow-helpers")) {
                    result.allowhelpers = std.mem.eql(u8, value, "true");
                } else {
                    return error.unknownkeyinpolicy;
                }
            },
            .none => {},
        }
    }


    // save last key
    if (currentid.len > 0) {
        switch (section) {
            .maintainers => try result.maintainers.put(currentid, current),
            .helpers => try result.helpers.put(currentid, current),
            .none, .hash, .policy => {},
        }
    }


    if (!foundkeys)
        return error.missingkeys;


    return result;
}