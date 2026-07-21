pub const Pkg = struct {
    src_url: []const u8 = "",
    sha256sum: []const u8 = "",
    strip: ?[]const u8 = null, // keep const so value in parser_s works (shitty fix)
    pre_hooks: ?[][]const u8 = null,
}; 

pub const Build = struct {
    build_sys: []const u8 = "",
    build_deps: ?[][]const u8 = null,
    args: ?[][]const u8 = null,
    script: ?[]const u8 = null, // exemped shell 
    post_hooks: ?[][]const u8 = null,
};

pub const Info = struct {
    homepage: []const u8 = "",
    upstream: []const u8 = "",
    name: []const u8 = "",
    version: []const u8 = "",
    desc: ?[]const u8 = null,
    license: ?[]const u8 = null,
    deps: ?[][]const u8 = null,
};

// spec, left for parser_tests.zig 
pub const Spec = struct {
    pkg: Pkg = .{},
    build: Build = .{},
};

// the file containing everything
pub const Xbuild = struct {
    info: Info = .{},
    pkg: Pkg = .{},
    build: Build = .{},
};


// will eventually get more values, more optionals, more complex things, architechture, etc, hence why kept in a seperate file this time
// uppercase naming convention for structs