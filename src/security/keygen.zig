//! this is a more 'developer exclusive' tool
//! however xpk is also made because you can easily host your own repos!
//! soon ill add even git support through private ones, if you feel like gatekeeping
//! so i keep this in the same binary for easy use, no point to start another repo.
//! altough, i might actually make this into a xpk tool like xpk-sign, but that will happen later
const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;
const globals = @import("../globals.zig");
const print = std.debug.print;

pub const Keygenerror = error{ keyalreadyexists, writefailed };

inline fn errprint(comptime fmt: []const u8, args: anytype) void {
    print("[x] " ++ fmt, args);
}

inline fn iprint(comptime fmt: []const u8, args: anytype) void {
    print("[*] " ++ fmt, args);
}

inline fn wprint(comptime fmt: []const u8, args: anytype) void {
    print("[!] " ++ fmt, args);
}

inline fn cprint(comptime fmt: []const u8, args: anytype) void {
    print("[+] " ++ fmt, args);
}



// where keypairs exist, these are not in globals because keygen ONLY appears here
pub fn keydir() []const u8 {
    return globals.base ++ "/keys";
}

fn privpath() []const u8 {
    return globals.base ++ "/keys/priv.key";
}

fn pubpath() []const u8 {
    return globals.base ++ "/keys/pub.key";
}

fn fingerprintpath() []const u8 {
    return globals.base ++ "/keys/fingerprint";
}

fn createdir(io: std.Io, path: []const u8) !void {
    std.Io.Dir.createDirAbsolute(io, path, .default_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}

// generates a new ed25519 keypair for signing index.bin, AND verifying
pub fn generate(io: std.Io) !void {
    try createdir(io, keydir());

    // refuse if a key already exists, if your key is corrupted, just make a commit with said
    // corrupted key and change it into another (if its pub, if priv key corrupts just post
    // attention warning but will need auditing)
    if (std.Io.Dir.openFileAbsolute(io, privpath(), .{ .mode = .read_only })) |f| {
        f.close(io);
        return Keygenerror.keyalreadyexists;
    } else |err| if (err != error.FileNotFound) return err;

    const kp = Ed25519.KeyPair.generate(io); // pure crypto, no io needed -- reads OS csprng internally

    // private key, 64 raw bytes, perms locked to owner-read/write only
    {
        const file = try std.Io.Dir.createFileAbsolute(io, privpath(), .{ .truncate = true });
        defer file.close(io);
        try file.setPermissions(io, std.Io.File.Permissions.fromMode(0o600)); // no window where its readable, should infact stay that way
        var writerbuf: [128]u8 = undefined;
        var fwriter = file.writer(io, &writerbuf);
        try fwriter.interface.writeAll(&kp.secret_key.bytes);
        try fwriter.interface.flush();
    }

    // public key, 32 raw bytes, world readable
    {
        const file = try std.Io.Dir.createFileAbsolute(io, pubpath(), .{ .truncate = true });
        defer file.close(io);
        try file.setPermissions(io, std.Io.File.Permissions.fromMode(0o644));
        var writerbuf: [64]u8 = undefined;
        var fwriter = file.writer(io, &writerbuf);
        try fwriter.interface.writeAll(&kp.public_key.toBytes());
        try fwriter.interface.flush();
    }

    // fingerprint file, hex encoded pubkey, this is what you paste into a repo's keyring.autm as `fingerprint = "..."` (only for maintainers/helpers)
    {
        const file = try std.Io.Dir.createFileAbsolute(io, fingerprintpath(), .{ .truncate = true });
        defer file.close(io);
        try file.setPermissions(io, std.Io.File.Permissions.fromMode(0o644));
        const hex = std.fmt.bytesToHex(kp.public_key.toBytes(), .lower);
        var writerbuf: [80]u8 = undefined;
        var fwriter = file.writer(io, &writerbuf);
        try fwriter.interface.writeAll(&hex);
        try fwriter.interface.writeAll("\n");
        try fwriter.interface.flush();
    }

    cprint("generated keypair \nfingerprint (paste into keyring.autm in the repo you want to be a maintainer/helper off, or give it to the owner if strict perms): {x}\nprivate key: {s} (chmod 600, back this up somewhere safe because losing it means re-keying every repo you maintain, and thats bad)\n", .{ kp.public_key.toBytes(), privpath() });
}

// loads the keypair for signing, if the key is exposed it errors and urges you to well, fix the thing duh, key_load
pub fn key_l(io: std.Io) !Ed25519.KeyPair {
    const file = try std.Io.Dir.openFileAbsolute(io, privpath(), .{ .mode = .read_only });
    defer file.close(io);

    const st = try file.stat(io);
    const mode = st.permissions.toMode() & 0o777;
    
    if (mode != 0o600) {
        wprint("{s} has loose permissions ({o}), expected 0600, not loading\n", .{ privpath(), mode });
        return error.insecurekeypermissions;
    }

    var buf: [64]u8 = undefined;
    var readbuf: [64]u8 = undefined;
    var freader = file.reader(io, &readbuf);
    try freader.interface.readSliceAll(&buf);

    const secret = Ed25519.SecretKey.fromBytes(buf) catch return error.corruptkey;
    return try Ed25519.KeyPair.fromSecretKey(secret);
}

// signs data with the given keypair, returns the raw 64-byte signature, thats it
pub fn sign(kp: Ed25519.KeyPair, data: []const u8) ![64]u8 {
    const sig = try kp.sign(data, null); // null = no extra entropy source
    return sig.toBytes();
}