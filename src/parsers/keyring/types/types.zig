const std = @import("std");

pub const Key = struct {
    fingerprint: []const u8 = "",
    added: []const u8 = "",
    active: bool = false, // defaults if not listed
    revoked: bool = false, // defaults
};

pub const Keyring = struct {
    maintainers: std.StringHashMap(Key), // first use of stringhash maps in my life, anyways here these are useful because maintainers and helpers do use the same string, and a hash map is useful here
    helpers: std.StringHashMap(Key),

    head: []const u8 = "", // default to nothing, but ill make these required some time for the sake of safety
    hashlastedit: []const u8 = "",

    requiredsigs: u32 = 1,
    allowhelpers: bool = true,
};