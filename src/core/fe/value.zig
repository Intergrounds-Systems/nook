pub const Value = union(enum) {
    val_bool: bool,
    val_int: i64,
    val_float: f64,
    val_str: []const u8,
    val_char: u8,
    val_void: void,
};

