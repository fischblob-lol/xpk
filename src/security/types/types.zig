pub const Keyentry = struct {
    id: []const u8,
    fingerprint: []const u8,
    role: []const u8,
    added: []const u8,
    active: bool,
    revoked: bool,
};