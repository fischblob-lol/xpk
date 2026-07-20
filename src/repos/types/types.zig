//! repo structure
//! will probably remain the same for eternity
pub const Repo = struct {
    name: []const u8 = "",
    url: []const u8 = "",
    priority: u8 = 0,
    enabled: bool = true,
};