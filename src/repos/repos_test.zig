const std = @import("std");
const testing = std.testing;
const parser = @import("repos.zig"); 


// default format for repos:
//
// [extra] # name
// url = "https://codeberg.org/sundowner/xpk-c" # url to codeberg, auto appends raw at the end
// priority = 0  # localwise, this is for automatically selecting priority and where you want to get packages from, though ill probably make this format different and more like interactive mid install, but for long dep chains ill prob just make it select priority first
// enabled = true # just to enable some repos, like on default you would want community or something off


// oh and these repos are testing (the package manager used to be called xpk before mist)

test "parse_r single repo, all fields" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[core]
        \\url = "https://codeberg.org/sundowner/xpk-c" # it should become /xpk-c/raw 
        \\priority = 0
        \\enabled = true
    ;

    const repos = try parser.parse_r(a, text);
    try testing.expectEqual(@as(usize, 1), repos.len);
    try testing.expectEqualStrings("core", repos[0].name);
    try testing.expectEqualStrings("https://codeberg.org/sundowner/xpk-c/raw", repos[0].url);
    try testing.expectEqual(@as(u8, 0), repos[0].priority);
    try testing.expect(repos[0].enabled);
}

test "parse_r multiple repos" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[core]
        \\url = "https://codeberg.org/sundowner/xpk-c"
        \\priority = 0
        \\enabled = true
        \\[extra]
        \\url = "https://codeberg.org/someone/xpk-extra"
        \\priority = 1
        \\enabled = false
    ;

    const repos = try parser.parse_r(a, text);
    try testing.expectEqual(@as(usize, 2), repos.len);

    try testing.expectEqualStrings("core", repos[0].name);
    try testing.expect(repos[0].enabled);

    try testing.expectEqualStrings("extra", repos[1].name);
    try testing.expectEqualStrings("https://codeberg.org/someone/xpk-extra/raw", repos[1].url);
    try testing.expectEqual(@as(u8, 1), repos[1].priority);
    try testing.expect(!repos[1].enabled);
}

test "parse_r no repos errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\# just a comment rineifokgjoig
    ;

    try testing.expectError(error.norepos, parser.parse_r(a, text));
}

test "parse_r invalid enabled value errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[core]
        \\url = "https://codeberg.org/sundowner/xpk-c"
        \\priority = 0
        \\enabled = maybeidk
    ;

    try testing.expectError(error.invalidbool, parser.parse_r(a, text));
}

test "parse_r comments and blank lines are ignored" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\# top comment
        \\[core]
        \\
        \\# inline explanation
        \\url = "https://codeberg.org/sundowner/xpk-c" # trailing note
        \\priority = 0
        \\enabled = true
        \\
    ;

    const repos = try parser.parse_r(a, text);
    try testing.expectEqual(@as(usize, 1), repos.len);
    try testing.expectEqualStrings("https://codeberg.org/sundowner/xpk-c/raw", repos[0].url);
}

test "parse_r lines before first section are ignored" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\url = "should not apply to anything" # good job
        \\[core]
        \\url = "https://codeberg.org/sundowner/xpk-c"
        \\priority = 0
        \\enabled = true
    ;

    const repos = try parser.parse_r(a, text);
    try testing.expectEqual(@as(usize, 1), repos.len);
    try testing.expectEqualStrings("https://codeberg.org/sundowner/xpk-c/raw", repos[0].url);
}

// basically all of these run