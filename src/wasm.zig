const std = @import("std");

extern "env" fn throw(message: [*]const u8, len: u32) noreturn;
extern "env" fn consoleLog(message: [*]const u8, len: u32) void;

fn log(comptime fmt: []const u8, args: anytype) void {
    const message = std.fmt.allocPrint(allocator, fmt, args) catch @panic("failed to format log message");
    consoleLog(message.ptr, message.len);
}

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    throw(message.ptr, message.len);
}

const allocator = std.heap.wasm_allocator;

export fn free(ptr: [*]u8, len: usize) void {
    allocator.free(ptr[0..len]);
}

export fn alloc(len: u32) [*]u8 {
    return (allocator.alloc(u8, len) catch unreachable).ptr;
}

const Complex = std.math.Complex(f32);

const mandelbrot = struct {
    const real_set = struct {
        const start = -2;
        const len = 4;
    };

    const imaginary_set = struct {
        const start = -2;
        const len = 4;
    };

    const max_iterations = 100;
    const max_iterations_f: f32 = @floatFromInt(max_iterations);

    const Color = struct { r: u8, g: u8, b: u8, a: u8 };

    fn mandelbrot(c: Complex) Color {
        var z = Complex.init(0, 0);
        for (0..max_iterations) |i| {
            z = z.mul(z).add(c);
            if (z.magnitude() > 4) {
                const e: f32 = @floatFromInt(i);
                const m: u8 = @intFromFloat(e / max_iterations_f * 255);
                return .{ .r = m, .g = m, .b = m, .a = 255 };
            }
        }
        return .{ .r = 0, .g = 0, .b = 0, .a = 255 };
    }
};

export fn draw(buffer: [*]u8, width: u32, height: u32, real_start: f32, imaginary_start: f32, scaled_width: f32) void {
    const width_f: f32 = @floatFromInt(width);
    const height_f: f32 = @floatFromInt(height);

    for (0..height) |y_int| {
        const y: f32 = @floatFromInt(y_int);

        for (0..width) |x_int| {
            const x: f32 = @floatFromInt(x_int);

            var c = Complex.init(
                real_start + x / width_f * scaled_width,
                imaginary_start + y / height_f * (scaled_width / width_f) * height_f,
            );

            const color = mandelbrot.mandelbrot(c);

            var red_index = (y_int * width + x_int) * 4;

            buffer[red_index] = color.r;
            buffer[red_index + 1] = color.g;
            buffer[red_index + 2] = color.b;
            buffer[red_index + 3] = color.a; // alpha
        }
    }
}
