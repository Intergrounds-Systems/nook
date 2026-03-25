const parser = @import("parser.zig");
const std = @import("std");
const tokenizer = @import("tokenizer.zig");

/// Tokenize source code into a stream of tokens
pub fn tokenize(allocator: std.mem.Allocator, source_code: []const u8) ![]tokenizer.Token {
    var t = tokenizer.Tokenizer.init(allocator, source_code);
    return t.tokenize();
}

/// Parse tokens into an list of statement trees
pub fn parse(allocator: std.mem.Allocator, tokens: []tokenizer.Token) !std.ArrayList(*parser.Stmt) {
    var p = parser.Parser.init(allocator, tokens);
    return p.parse();
}
