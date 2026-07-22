const std = @import("std");
const testing = std.testing;
const parser = @import("buildparser.zig"); 
const types = @import("types/types.zig");

// production code test

test "parse_a valid full manifest parses info, pkg, and build" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[info]
        \\homepage = "https://github.com/abishekvashok/cmatrix"
        \\upstream = "abishekvashok"
        \\name = "cmatrix"
        \\version = "2.0"
        \\desc = "Terminal based 'The Matrix' like implementation"
        \\license = "GPL-3.0"
        \\deps = []
        \\# comment
        \\[pkg]
        \\# comment, messy stuff here
        \\src-url = "https://github.com/abishekvashok/cmatrix/archive/refs/tags/v2.0.tar.gz"
        \\sha256 = "ad93ba39acd383696ab6a9ebbed1259ecf2d3cf9f49d6b97038c66f80749e99a"
        \\strip = "1"
        \\pre-hooks = [
        \\  "autoreconf -i"
        \\]
        \\# this is just shell
        \\[build]
        \\build-sys = "autotools"
        \\# oh yeah, and 'script' is also gonna be a optional variable incase scripts need to be ran, some packages do this
        \\post-hooks = []
    ;

    const m = try parser.parse_a(a, text);

    // info
    try testing.expectEqualStrings("cmatrix", m.info.name);
    try testing.expectEqualStrings("2.0", m.info.version);
    try testing.expectEqualStrings("abishekvashok", m.info.upstream.?);
    try testing.expectEqualStrings("https://github.com/abishekvashok/cmatrix", m.info.homepage);
    try testing.expectEqualStrings("GPL-3.0", m.info.license.?);
    try testing.expect(m.info.deps == null);

    // pkg
    try testing.expectEqualStrings(
        "https://github.com/abishekvashok/cmatrix/archive/refs/tags/v2.0.tar.gz",
        m.pkg.src_url,
    );
    try testing.expectEqualStrings(
        "ad93ba39acd383696ab6a9ebbed1259ecf2d3cf9f49d6b97038c66f80749e99a",
        m.pkg.sha256sum,
    );
    try testing.expectEqualStrings("1", m.pkg.strip.?);
    const hooks = m.pkg.pre_hooks.?;
    try testing.expectEqual(@as(usize, 1), hooks.len);
    try testing.expectEqualStrings("autoreconf -i", hooks[0]);

    // build
    try testing.expectEqualStrings("autotools", m.build.build_sys);
    try testing.expect(m.build.script == null);
    try testing.expect(m.build.post_hooks == null); 
}




// old tests!!!
// old tests!!!
// old tests!!!
// old tests!!!
// old tests!!!
// old tests!!!
// still good since i will figure out how everything can work, so ill keep parse_i and such
// ARCHIVED



//[info]
//homepage = "https://github.com/abishekvashok/cmatrix"
//upstream.? = "weputnameshere"
//name = "cmatrix"
//version = "2.0"
//desc = "Terminal based 'The Matrix' like implementation"
//license = "GPL-3.0"
//deps = []
//# comment

test "parse_i valid info parses all fields" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[info]
        \\homepage = "https://github.com/abishekvashok/cmatrix"
        \\upstream = "abishekvashok"
        \\name = "cmatrix"
        \\version = "2.0"
        \\desc = "Terminal based Matrix implementation"
        \\license = "GPL-3.0"
        \\deps = []
    ;

    const m = try parser.parse_i(a, text);
    try testing.expectEqualStrings("cmatrix", m.name);
    try testing.expectEqualStrings("2.0", m.version);
    try testing.expectEqualStrings("abishekvashok", m.upstream.?);
    try testing.expectEqualStrings("https://github.com/abishekvashok/cmatrix", m.homepage);
    try testing.expect(m.deps == null);
}

test "parse_i missing info section errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[pkg]
        \\src-url = "https://example.com/x.tar.gz"
    ;

    try testing.expectError(error.missinginfo, parser.parse_i(a, text));
}



test "parse_i single-line deps array parses correctly" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[info]
        \\upstream = "someone"
        \\deps = ["thing", "other thing"]
    ;

    const m = try parser.parse_i(a, text);
    try testing.expect(m.deps != null);
    const deps = m.deps.?;
    try testing.expectEqual(@as(usize, 2), deps.len);
    try testing.expectEqualStrings("thing", deps[0]);
    try testing.expectEqualStrings("other thing", deps[1]);
}

test "parse_i multi-line deps array parses correctly" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[info]
        \\upstream.? = "a guy"
        \\deps = [
        \\    "foo",
        \\    "bar",
        \\]
    ;

    const m = try parser.parse_i(a, text);
    const deps = m.deps.?;
    try testing.expectEqual(@as(usize, 2), deps.len);
    try testing.expectEqualStrings("foo", deps[0]);
    try testing.expectEqualStrings("bar", deps[1]);
}

test "parse_i comments are stripped, including inline" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[info]
        \\# a comment line
        \\upstream = "someone" # inline comment
        \\name = "cmatrix"
    ;

    const m = try parser.parse_i(a, text);
    try testing.expectEqualStrings("someone", m.upstream.?);
    try testing.expectEqualStrings("cmatrix", m.name);
}

test "parse_i sections after info don't leak in" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[info]
        \\upstream.? = "someone"
        \\name = "cmatrix"
        \\[pkg]
        \\name = "should not overwrite info name"
    ;

    const m = try parser.parse_i(a, text);
    try testing.expectEqualStrings("cmatrix", m.name);
}

// parse_s tests

// this is how a FULL buildfile should look like
// [pkg]
//# comment, messy stuff here
//src-url = "https://github.com/abishekvashok/cmatrix/archive/refs/tags/v2.0.tar.gz"
//sha256sum = "ad93ba39acd383696ab6a9ebbed1259ecf2d3cf9f49d6b97038c66f80749e99a"
//folder = "cmatrix-2.0" # optional btw, this is just double extraction with a neat name

//pre-hooks = []
//# this is just shell

//[build]
//build-sys = "cmake"
//# oh yeah, and 'script' is also gonna be a optional variable incase scripts need to be ran, some packages do this
//build-deps = ["cmake"]
//script = "fuck.sh" # should probably automatically chmod? or i guess that should be auto done anyways
//args = [
//    "-DENABLE_TESTS=OFF",
//    "-DCMAKE_BUILD_TYPE=Release",
//]

//post-hooks = []
//# shell inside current build folder after build
//# to not get arbitary execution, permissions in shell will be limited LIKEWISE with post and pre-hooks

test "parse_s valid build file parses all sections" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[pkg]
        \\src-url = "https://github.com/abishekvashok/cmatrix/archive/refs/tags/v2.0.tar.gz"
        \\sha256sum = "ad93ba39acd383696ab6a9ebbed1259ecf2d3cf9f49d6b97038c66f80749e99a"
        \\strip = "1"
        \\pre-hooks = []
        \\[build]
        \\build-sys = "cmake"
        \\script = "download.sh" 
        \\args = [
        \\    "-DENABLE_TESTS=OFF",
        \\    "-DCMAKE_BUILD_TYPE=Release",
        \\]
        \\post-hooks = []
    ;

    const bf = try parser.parse_s(a, text);
    try testing.expectEqualStrings(
        "https://github.com/abishekvashok/cmatrix/archive/refs/tags/v2.0.tar.gz",
        bf.pkg.src_url,
    );
    try testing.expectEqualStrings("cmake", bf.build.build_sys);
    try testing.expect(bf.pkg.strip != null);
    try testing.expectEqualStrings("1", bf.pkg.strip.?);
    try testing.expectEqualStrings("download.sh", bf.build.script.?);

    const args = bf.build.args.?;
    try testing.expectEqual(@as(usize, 2), args.len);
    try testing.expectEqualStrings("-DENABLE_TESTS=OFF", args[0]);
    try testing.expectEqualStrings("-DCMAKE_BUILD_TYPE=Release", args[1]);
}

test "parse_s missing pkg section errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[build]
        \\build-sys = "cmake"
    ;

    try testing.expectError(error.missingpkg, parser.parse_s(a, text));
}

test "parse_s missing build section errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[pkg]
        \\src-url = "https://example.com/x.tar.gz"
        \\sha256sum = "jewdshjfkesfdhfsejrwsfdnsi3wrkesfjek"
    ;

    try testing.expectError(error.missingbuild, parser.parse_s(a, text));
}

test "parse_s missing src-url errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[pkg]
        \\sha256sum = "jajedskefjdnjkrfnbdjkefsrv"
        \\[build]
        \\build-sys = "cmake"
    ;

    try testing.expectError(error.missingsrcurl, parser.parse_s(a, text));
}

test "parse_s missing sha256sum errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[pkg]
        \\src-url = "https://example.com/x.tar.gz"
        \\[build]
        \\build-sys = "cmake"
    ;

    try testing.expectError(error.missingsha256sum, parser.parse_s(a, text));
}

test "parse_s build-deps single-line parses correctly" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[pkg]
        \\src-url = "https://example.com/x.tar.gz"
        \\sha256sum = "fjrrehwdsfikejrwejfsd"
        \\[build]
        \\build-sys = "cmake"
        \\build-deps = ["gcc", "make"]
    ;

    const bf = try parser.parse_s(a, text);
    const deps = bf.build.build_deps.?;
    try testing.expectEqual(@as(usize, 2), deps.len);
    try testing.expectEqualStrings("gcc", deps[0]);
    try testing.expectEqualStrings("make", deps[1]);
}

// a little funky, because when i made the parser the dependencies don't really parse well sometimes..? idk, i couldn't find a flaw in my logic and it usually worked.
// also, getting multiline deps working took some time too

test "parse_s build-deps multi-line parses correctly" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[pkg]
        \\src-url = "https://example.com/x.tar.gz"
        \\sha256sum = "fnjdedfjukejdjufijfd"
        \\[build]
        \\build-sys = "cmake"
        \\build-deps = [
        \\    "gcc",
        \\    "make",
        \\]
    ;

    const bf = try parser.parse_s(a, text);
    const deps = bf.build.build_deps.?;
    try testing.expectEqual(@as(usize, 2), deps.len);
    try testing.expectEqualStrings("gcc", deps[0]);
    try testing.expectEqualStrings("make", deps[1]);
}

test "parse_s no build-deps leaves field null" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[pkg]
        \\src-url = "https://example.com/x.tar.gz"
        \\sha256sum = "ejnwfksdijnjrefsd"
        \\[build]
        \\build-sys = "cmake"
    ;

    const bf = try parser.parse_s(a, text);
    try testing.expect(bf.build.build_deps == null);
}

test "parse_s pkg-only fields don't leak into build section" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const text =
        \\[pkg]
        \\src-url = "https://example.com/x.tar.gz"
        \\sha256sum = "jfnkendsjifsnd"
        \\build-sys = "shantapplyhere"
        \\[build]
        \\build-sys = "cmake"
    ;

    const bf = try parser.parse_s(a, text);
    try testing.expectEqualStrings("cmake", bf.build.build_sys);
}
