const std = @import("std");
const http = std.http;
const net = std.net;

const addr = net.Address.resolveIp("127.0.0.1", 8000) catch unreachable;

const index_response = std.fmt.comptimePrint(
    \\<!DOCTYPE html>
    \\<html lang="en">
    \\    <head>
    \\        <meta charset="utf-8">
    \\        <meta name="viewport" content="width=device-width,initial-scale=1">
    \\        <title>App</title>
    \\        <style>{s}</style>
    \\    </head>
    \\    <body
    \\        class="w-full h-full grid place-items-center gap-4"
    \\        x-data="{{
    \\            ctx: undefined,
    \\            realStart: -2,
    \\            imaginaryStart: -2,
    \\            scaledWidth: 4,
    \\            center(x, y) {{
    \\                this.realStart = x - this.scaledWidth / 2;
    \\                this.imaginaryStart = y - this.scaledWidth / 2;
    \\            }},
    \\            zoom(amount) {{
    \\                const oldScaledWidth = this.scaledWidth;
    \\                this.scaledWidth *= 1 / amount;
    \\                this.realStart -= (this.scaledWidth - oldScaledWidth) / 2;
    \\                this.imaginaryStart -= (this.scaledWidth - oldScaledWidth) / 2;
    \\            }}
    \\        }}"
    \\    >
    \\        <canvas
    \\            class="h-max aspect-square rounded cursor-pointer"
    \\            width="512"
    \\            height="512"
    \\            x-init="ctx = $el.getContext('2d');"
    \\            x-effect="drawCanvas($data)"
    \\            @click="center(
    \\                realStart + $event.offsetX / $el.width * scaledWidth,
    \\                imaginaryStart + $event.offsetY / $el.height * scaledWidth
    \\            )"
    \\         >
    \\        </canvas>
    \\        <div class="flex flex-wrap gap-4">
    \\            <button @click="zoom(1 / 1.5)">-</button>
    \\            <button @click="zoom(1.5)">+</button>
    \\            <button @click="scaledWidth = 4; realStart = -2; imaginaryStart = -2">Reset</button>
    \\        </div>
    \\        <script>{s}</script>
    \\    </body>
    \\</html>
, .{
    @embedFile("../zig-out/embed/style.css"),
    @embedFile("../zig-out/embed/script.js"),
});

const wasm_response = @embedFile("../zig-out/lib/zig-wasm.wasm");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var server = http.Server.init(allocator, .{ .reuse_address = true });
    defer server.deinit();

    try server.listen(addr);

    std.log.info("listening on http://{}...", .{addr});

    outer: while (true) {
        var arena_allocator = std.heap.ArenaAllocator.init(allocator);
        defer arena_allocator.deinit();

        var response = try server.accept(.{ .allocator = arena_allocator.allocator() });
        defer response.deinit();

        while (response.reset() != .closing) {
            response.wait() catch |err| switch (err) {
                error.HttpHeadersInvalid => continue :outer,
                error.EndOfStream => continue,
                else => return err,
            };

            handleRequest(&response) catch continue;
        }
    }
}

fn handleRequest(response: *http.Server.Response) !void {
    const request = response.request;
    std.log.info("{s} {s} {s}", .{ @tagName(request.method), @tagName(request.version), request.target });

    const allocator = response.allocator;

    const body = try response.reader().readAllAlloc(allocator, 8192);
    defer allocator.free(body);

    if (request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    if (std.mem.eql(u8, request.target, "/")) {
        try response.headers.append("Content-Type", "text/html");
        response.transfer_encoding = .{ .content_length = index_response.len };

        try response.do();

        if (request.method != .HEAD) {
            try response.writeAll(index_response);
            try response.finish();
        }

        return;
    }

    if (std.mem.eql(u8, request.target, "/zig-wasm.wasm")) {
        try response.headers.append("Content-Type", "application/wasm");
        response.transfer_encoding = .{ .content_length = wasm_response.len };

        try response.do();

        if (request.method != .HEAD) {
            try response.writeAll(wasm_response);
            try response.finish();
        }

        return;
    }

    response.status = .not_found;
    response.transfer_encoding = .{ .content_length = 0 };
    try response.do();
    try response.finish();
}
