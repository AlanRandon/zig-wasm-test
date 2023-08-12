const std = @import("std");
const http = std.http;
const net = std.net;

const addr = net.Address.resolveIp("127.0.0.1", 8000) catch unreachable;

pub fn main() !void {
    // TODO: finish server: `https://blog.orhun.dev/zig-bits-04/`

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var server = http.Server.init(allocator, .{});
    defer server.deinit();

    try server.listen(addr);

    std.log.info("listening on {}...\n", .{addr});

    while (true) {
        var arena_allocator = std.heap.ArenaAllocator.init(allocator);
        defer arena_allocator.deinit();
        var response = try server.accept(.{ .allocator = arena_allocator.allocator() });
        defer response.deinit();

        response.wait() catch continue;
        try response.do();
        try response.writeAll("<h1>Hello World</h1>");
        try response.finish();
    }
}
