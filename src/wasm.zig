const std = @import("std");

extern "env" fn throw(message: [*]const u8, length: u32) noreturn;
extern "env" fn log(message: [*]const u8, length: u32) void;

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    throw(message.ptr, message.len);
}

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}
