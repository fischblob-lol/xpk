const std = @import("std");


// due to how often these guys are used i decided to just put them in one file to avoid duplicating a shit ton of code, also duplicated FOR SOME TIME 
// check note.txt on what im planning to do, most of these dirs wont even use stripl, because they gonna jus be wrappers
pub fn strip_comment(line: []const u8) []const u8 {
    var quoted = false;
    for (line, 0..) | c, i | {
        if (c == '"') quoted = !quoted;
        if (c == '#' and !quoted) return std.mem.trim(u8, line[0..i], " \t\r");
    }
    return std.mem.trim(u8, line, " \t\r");
} 

pub fn parse_quoted(value: []const u8) []const u8 {
    const trimmed = std.mem.trim(u8, value, " \t");
    if (trimmed.len >= 2 and trimmed[0] == '"' and trimmed[trimmed.len - 1] == '"') {
        return trimmed[1 .. trimmed.len - 1];
    }
    return trimmed;
}