const std = @import("std");
const types = @import("types/types.zig");
const print = std.debug.print;

// strip comment and parse quoted made a function so i don't have to implement ts all the time
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

// parse_a - combined parser, one file has [info], [pkg], and [build] all together.
// merge of parse_i and parse_s, this is for production code
// eventually, both [pkg] and [build] will become OPTIONAL but will get a warning (this is because we eventually become a binary/hybrid package manager)
pub fn parse_a(allocator: std.mem.Allocator, text: []const u8) !types.Xbuild {
    var result: types.Xbuild = .{};
    var section: enum { none, info, pkg, build } = .none;
    var foundinfo = false;
    var foundpkg = false;
    var foundbuild = false;

    var deplist: std.ArrayList([]const u8) = .empty;
    var builddeps: std.ArrayList([]const u8) = .empty;
    var prehooks: std.ArrayList([]const u8) = .empty;
    var posthooks: std.ArrayList([]const u8) = .empty;
    var argslist: std.ArrayList([]const u8) = .empty;
    var pendingarr: ?*std.ArrayList([]const u8) = null;

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |rawline| {
        const line = strip_comment(rawline);
        if (line.len == 0) continue;

        // multiline array, works for deps AND the spec arrays now
        if (pendingarr) |list| {
            if (std.mem.eql(u8, line, "]")) {
                pendingarr = null;
                continue;
            }
            const item = std.mem.trim(u8, line, " \t,");
            if (item.len == 0) continue;
            try list.append(allocator, parse_quoted(item));
            continue;
        }

        // section header
        if (line[0] == '[' and line[line.len - 1] == ']') {
            const name = line[1 .. line.len - 1];
            if (std.mem.eql(u8, name, "info")) {
                section = .info;
                foundinfo = true;
            } else if (std.mem.eql(u8, name, "pkg")) {
                section = .pkg;
                foundpkg = true;
            } else if (std.mem.eql(u8, name, "build")) {
                section = .build;
                foundbuild = true;
            } else section = .none;
            continue;
        }

        if (section == .none) continue;

        const eqidx = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..eqidx], " \t");
        var value = std.mem.trim(u8, line[eqidx + 1 ..], " \t");

        // info arrays
        if (section == .info and std.mem.eql(u8, key, "deps")) {
            if (value.len >= 2 and value[0] == '[' and value[value.len - 1] == ']') {
                const inner = std.mem.trim(u8, value[1 .. value.len - 1], " \t");
                if (inner.len > 0) {
                    var items = std.mem.splitScalar(u8, inner, ',');
                    while (items.next()) |item| {
                        const trimmed = std.mem.trim(u8, item, " \t");
                        if (trimmed.len == 0) continue;
                        try deplist.append(allocator, parse_quoted(trimmed));
                    }
                }
            } else if (value.len > 0 and value[0] == '[') {
                pendingarr = &deplist;
            }
            continue;
        }

        // pkg builds
        if ((section == .pkg or section == .build) and value.len > 0 and value[0] == '[') {
            var target: *std.ArrayList([]const u8) = undefined;
            if (std.mem.eql(u8, key, "pre-hooks")) target = &prehooks
            else if (std.mem.eql(u8, key, "post-hooks")) target = &posthooks
            else if (std.mem.eql(u8, key, "args")) target = &argslist
            else if (std.mem.eql(u8, key, "build-deps")) target = &builddeps
            else continue;

            if (value.len >= 2 and value[value.len - 1] == ']') {
                const inner = std.mem.trim(u8, value[1 .. value.len - 1], " \t");
                if (inner.len > 0) {
                    var items = std.mem.splitScalar(u8, inner, ',');
                    while (items.next()) |item| {
                        const trimmed = std.mem.trim(u8, item, " \t");
                        if (trimmed.len == 0) continue;
                        try target.append(allocator, parse_quoted(trimmed));
                    }
                }
            } else {
                pendingarr = target;
            }
            continue;
        }

        value = parse_quoted(value);

        // non array stuff
        switch (section) {
            .info => {
                if (std.mem.eql(u8, key, "homepage")) result.info.homepage = value
                else if (std.mem.eql(u8, key, "upstream")) result.info.upstream = value
                else if (std.mem.eql(u8, key, "name")) result.info.name = value
                else if (std.mem.eql(u8, key, "version")) result.info.version = value
                else if (std.mem.eql(u8, key, "desc")) result.info.desc = value
                else if (std.mem.eql(u8, key, "license")) result.info.license = value;
            },
            .pkg => {
                if (std.mem.eql(u8, key, "src-url")) result.pkg.src_url = value
                else if (std.mem.eql(u8, key, "sha256")) result.pkg.sha256sum = value
                else if (std.mem.eql(u8, key, "strip")) {
                    if (!(std.mem.eql(u8, value, "1") or
                        std.mem.eql(u8, value, "2") or
                        std.mem.eql(u8, value, "3")))
                    {
                        return error.badstripabove3;
                    }
                    result.pkg.strip = value;
                }
            },
            .build => {
                if (std.mem.eql(u8, key, "build-sys")) result.build.build_sys = value
                else if (std.mem.eql(u8, key, "script")) result.build.script = value;
            },
            .none => {},
        }
    }

    // errors, union of both original errors
    if (!foundinfo) return error.missinginfo;
    if (result.info.upstream.len == 0) return error.missingupstream;
    if (!foundpkg) return error.missingpkg;
    if (!foundbuild) return error.missingbuild;
    if (result.pkg.src_url.len == 0) return error.missingsrcurl;
    if (result.pkg.sha256sum.len == 0) return error.missingsha256sum;

    if (deplist.items.len > 0) result.info.deps = try deplist.toOwnedSlice(allocator);
    if (prehooks.items.len > 0) result.pkg.pre_hooks = try prehooks.toOwnedSlice(allocator);
    if (posthooks.items.len > 0) result.build.post_hooks = try posthooks.toOwnedSlice(allocator);
    if (argslist.items.len > 0) result.build.args = try argslist.toOwnedSlice(allocator);
    if (builddeps.items.len > 0) result.build.build_deps = try builddeps.toOwnedSlice(allocator);

    return result;
}

// ARCHIVED CODE
// IF YOU ARE READING THIS, THE FUNCTIONS BELOW ARE ONLY USED FOR TESTS AND ARE NOT USED IN PRODUCTION CODE!!
// IF YOU ARE READING THIS, THE FUNCTIONS BELOW ARE ONLY USED FOR TESTS AND ARE NOT USED IN PRODUCTION CODE!!
// IF YOU ARE READING THIS, THE FUNCTIONS BELOW ARE ONLY USED FOR TESTS AND ARE NOT USED IN PRODUCTION CODE!!
// IF YOU ARE READING THIS, THE FUNCTIONS BELOW ARE ONLY USED FOR TESTS AND ARE NOT USED IN PRODUCTION CODE!!
// IF YOU ARE READING THIS, THE FUNCTIONS BELOW ARE ONLY USED FOR TESTS AND ARE NOT USED IN PRODUCTION CODE!!
// IF YOU ARE READING THIS, THE FUNCTIONS BELOW ARE ONLY USED FOR TESTS AND ARE NOT USED IN PRODUCTION CODE!! 
// (why?): answer: this used to parse 2 different files from the web, which was as you know inefficent asf, but since they contain the core logic of parse_a i keep them for TESTS and tests only (yes its messy, but eventually ill js make a bunch of tests for parse_a)

//parse_info
pub fn parse_i(allocator: std.mem.Allocator, text: []const u8) !types.Info {
    var m: types.Info = .{};
    var ininfo = false;
    var foundinfo = false;

    var deplist: std.ArrayList([]const u8) = .empty;
    var pendingarr = false;

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |rawline| {
        const line = strip_comment(rawline);
        if (line.len == 0) continue;

        // multi line arrays sir
        if (pendingarr) {
            if (std.mem.eql(u8, line, "]")) {
                pendingarr = false;
                continue;
            }
            const item = std.mem.trim(u8, line, " \t,");
            if (item.len == 0) continue;
            try deplist.append(allocator, parse_quoted(item));
            continue;
        }
        // finds info
        if (line[0] == '[' and line[line.len - 1] == ']') {
            const name = line[1 .. line.len - 1];
            ininfo = std.mem.eql(u8, name, "info");
            if (ininfo) foundinfo = true;
            continue;
        }

        if (!ininfo) continue;  

        const eqidx = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..eqidx], " \t");
        var value = std.mem.trim(u8, line[eqidx + 1 ..], " \t");

        // logic for dependencies, split by a delimiter of , so deps would go like deps = ["thing", "other thing"] , multiline logic is also below so it does this too
        if (std.mem.eql(u8, key, "deps")) {
            if (value.len >= 2 and value[0] == '[' and value[value.len - 1] == ']') {
                const inner = std.mem.trim(u8, value[1 .. value.len - 1], " \t");
                if (inner.len > 0) {
                    var items = std.mem.splitScalar(u8, inner, ',');
                    while (items.next()) |item| {
                        const trimmed = std.mem.trim(u8, item, " \t");
                        if (trimmed.len == 0) continue;
                        try deplist.append(allocator, parse_quoted(trimmed));
                    }
                }
            } else if (value.len > 0 and value[0] == '[') {
                pendingarr = true; // multi-line deps
            }
            continue;
        }

        value = parse_quoted(value);

        if (std.mem.eql(u8, key, "homepage")) m.homepage = value
        else if (std.mem.eql(u8, key, "upstream")) m.upstream = value
        else if (std.mem.eql(u8, key, "name")) m.name = value
        else if (std.mem.eql(u8, key, "version")) m.version = value
        else if (std.mem.eql(u8, key, "desc")) m.desc = value
        else if (std.mem.eql(u8, key, "license")) m.license = value;
    }

    // errors
    if (!foundinfo) return error.missinginfo;
    if (m.upstream.len == 0) return error.missingupstream;
    if (deplist.items.len > 0) m.deps = try deplist.toOwnedSlice(allocator);

    return m;
}

// parse_spec, this one is a basic copy of parse_i except everything decided to become an array
pub fn parse_s(allocator: std.mem.Allocator, text: []const u8) !types.Spec {
    var result: types.Spec = .{};
    var section: enum { none, pkg, build } = .none;
    var foundpkg = false;
    var foundbuild = false;


    var builddeps: std.ArrayList([]const u8) = .empty;
    var prehooks: std.ArrayList([]const u8) = .empty;
    var posthooks: std.ArrayList([]const u8) = .empty;
    var argslist: std.ArrayList([]const u8) = .empty;
    var pendingarr: ?*std.ArrayList([]const u8) = null;

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |rawline| {
        const line = strip_comment(rawline);
        if (line.len == 0) continue;

        if (pendingarr) |list| {
            if (std.mem.eql(u8, line, "]")) {
                pendingarr = null;
                continue;
            }
            const item = std.mem.trim(u8, line, " \t,");
            if (item.len == 0) continue;
            try list.append(allocator, parse_quoted(item));
            continue;
        }
        // just looks at wether we are inside pkg or build
        if (line[0] == '[' and line[line.len - 1] == ']') {
            const name = line[1 .. line.len - 1];
            if (std.mem.eql(u8, name, "pkg")) {
                section = .pkg;
                foundpkg = true;
            } else if (std.mem.eql(u8, name, "build")) {
                section = .build;
                foundbuild = true;
            } else section = .none;
            continue;
        }

        if (section == .none) continue;
        
        // STRAIGHT copy pasted out of neo exact lines btw (except the name eqidx)
        const eqidx = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..eqidx], " \t");
        var value = std.mem.trim(u8, line[eqidx + 1 ..], " \t");

        // array valued keys, took some logic from neo
        if (value.len > 0 and value[0] == '[') {
            var target: *std.ArrayList([]const u8) = undefined;
            if (std.mem.eql(u8, key, "pre-hooks")) target = &prehooks
            else if (std.mem.eql(u8, key, "post-hooks")) target = &posthooks
            else if (std.mem.eql(u8, key, "args")) target = &argslist
            else if (std.mem.eql(u8, key, "build-deps")) target = &builddeps
            else continue;

            if (value.len >= 2 and value[value.len - 1] == ']') {
                const inner = std.mem.trim(u8, value[1 .. value.len - 1], " \t");
                if (inner.len > 0) {
                    var items = std.mem.splitScalar(u8, inner, ',');
                    while (items.next()) |item| {
                        const trimmed = std.mem.trim(u8, item, " \t");
                        if (trimmed.len == 0) continue;
                        try target.append(allocator, parse_quoted(trimmed));
                    }
                }
            } else {
                pendingarr = target;
            }
            continue;
        }
        // lowk might rename to parse_q?
        value = parse_quoted(value);
        

        // genius move right here watch i make a switch case. and i put non arrays in their place quickly, only works here because xbuild contains 2 structs, also these are non arrays
        switch (section) {
            .pkg => {
                if (std.mem.eql(u8, key, "src-url")) result.pkg.src_url = value
                else if (std.mem.eql(u8, key, "sha256sum")) result.pkg.sha256sum = value 
                else if (std.mem.eql(u8, key, "strip")) {
                if (!(std.mem.eql(u8, value, "1") or
                    std.mem.eql(u8, value, "2") or
                    std.mem.eql(u8, value, "3")))
                {
                    return error.invalidstripabove3;
                }

                result.pkg.strip = value;
            }
            },
            .build => {
                if (std.mem.eql(u8, key, "build-sys")) result.build.build_sys = value
                else if (std.mem.eql(u8, key, "script")) result.build.script = value;
            },
            .none => {},
        }
    }
    // errors again
    if (!foundpkg) return error.missingpkg;
    if (!foundbuild) return error.missingbuild;
    if (result.pkg.src_url.len == 0) return error.missingsrcurl;
    if (result.pkg.sha256sum.len == 0) return error.missingsha256sum;

    // arrays in their place slowly
    if (prehooks.items.len > 0) result.pkg.pre_hooks = try prehooks.toOwnedSlice(allocator);
    if (posthooks.items.len > 0) result.build.post_hooks = try posthooks.toOwnedSlice(allocator);
    if (argslist.items.len > 0) result.build.args = try argslist.toOwnedSlice(allocator);
    if (builddeps.items.len > 0) result.build.build_deps = try builddeps.toOwnedSlice(allocator);

    return result;
}