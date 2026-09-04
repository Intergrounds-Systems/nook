const parser = @import("parser.zig");
const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const types = @import("types");

/// Tokenize source code into a stream of tokens
pub fn tokenize(allocator: std.mem.Allocator, source_code: []const u8) ![]types.Token {
    var t = tokenizer.Tokenizer.init(allocator, source_code);
    return t.tokenize();
}

/// Parse tokens into an list of statement trees
pub fn parse(allocator: std.mem.Allocator, tokens: []types.Token) !std.ArrayList(*types.Stmt) {
    var p = parser.Parser.init(allocator, tokens);
    return p.parse();
}
