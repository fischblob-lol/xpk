const std = @import("std");
const parser = @import("keyring.zig");
const testing = std.testing;

// default format for keyrings:
//
// [hash]
// head = "latest hash, not the same as keyring edited"
// last-edit = "when keyring was edited hash" 
//
// [policy]
// required-signatures = 2 // amount of maintainer signatures required
// allow-helpers = true // whether helper signatures are accepted
//
// [maintainers.aurelius] // id
// fingerprint = "28ffbe73708a580e0db48025e4eed616dcbadc9e865f436fb00c08cd1bdb107"
// added = "21/7/2026 18:42 UTC" # 
// active = true
// revoked = false
//
// [helpers.someone] // id
// fingerprint = "..."
// added = "..."
// active = true
// revoked = false

test "parse_k single maintainer with all fields" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[hash]
        \\head = "abc123"
        \\last-edit = "def456"
        \\
        \\[maintainers.aurelius]
        \\fingerprint = "28ffbe73708a580e0db48025e4eed616dcbadc9e865f436fb00c08cd1bdb107"
        \\added = "2026-07-21"
        \\active = true
        \\revoked = false
        \\
        \\[policy]
        \\required-signatures = 2
        \\allow-helpers = true
    ;

    const keyring = try parser.parse_k(a, text);

    try testing.expectEqualStrings("abc123", keyring.head);
    try testing.expectEqualStrings("def456", keyring.hashlastedit);

    const key = keyring.maintainers.get("aurelius").?;

    try testing.expectEqualStrings(
        "28ffbe73708a580e0db48025e4eed616dcbadc9e865f436fb00c08cd1bdb107",
        key.fingerprint,
    );
    try testing.expectEqualStrings("2026-07-21", key.added);
    try testing.expect(key.active);
    try testing.expect(!key.revoked);

    try testing.expectEqual(@as(u32, 2), keyring.requiredsigs);
    try testing.expect(keyring.allowhelpers);
}


test "parse_k multiple maintainers and helpers" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[maintainers.aurelius]
        \\fingerprint = "aaa"
        \\added = "2026-07-21"
        \\active = true
        \\revoked = false
        \\
        \\[maintainers.other]
        \\fingerprint = "bbb"
        \\added = "2026-07-22"
        \\active = true
        \\revoked = false
        \\
        \\[helpers.helper]
        \\fingerprint = "ccc"
        \\added = "2026-07-22"
        \\active = true
        \\revoked = false
    ;

    const keyring = try parser.parse_k(a, text);

    try testing.expectEqual(@as(usize, 2), keyring.maintainers.count());
    try testing.expectEqual(@as(usize, 1), keyring.helpers.count());

    try testing.expectEqualStrings(
        "aaa",
        keyring.maintainers.get("aurelius").?.fingerprint,
    );

    try testing.expectEqualStrings(
        "ccc",
        keyring.helpers.get("helper").?.fingerprint,
    );
}


test "parse_k comments and blank lines are ignored" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\# keyring comment
        \\
        \\[maintainers.aurelius]
        \\fingerprint = "abc" # fingerprint comment
        \\added = "2026-07-21"
        \\active = true
        \\revoked = false
    ;

    const keyring = try parser.parse_k(a, text);

    const key = keyring.maintainers.get("aurelius").?;

    try testing.expectEqualStrings("abc", key.fingerprint);
}


test "parse_k no keys errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\# nothing here
    ;

    try testing.expectError(error.missingkeys, parser.parse_k(a, text));
}


test "parse_k invalid section errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[random.aurelius]
        \\fingerprint = "abc"
    ;

    try testing.expectError(error.badkeysection, parser.parse_k(a, text));
}


test "parse_k invalid key errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[maintainers.aurelius]
        \\fingerprint = "abc"
        \\unknown = "lol"
    ;

    try testing.expectError(error.unknownkeyinkeyring, parser.parse_k(a, text));
}


test "parse_k invalid policy values errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[policy]
        \\required-signatures = nope
    ;
    // had to double rn to make sure 
    try testing.expectError(error.InvalidCharacter, parser.parse_k(a, text));
}