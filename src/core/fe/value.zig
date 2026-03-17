pub const Value = union(enum) {
    Bool: bool,
    Integer: i64,
    Float: f64,
    String: []const u8,
    Char: u8,
    Void: void,
};
