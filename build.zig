const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const wasm_lib = b.addSharedLibrary(.{
        .name = "zig-wasm",
        .root_source_file = .{ .path = "src/wasm.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = optimize,
    });

    // wasm_lib.export_symbol_names = &.{"add"};

    // needed for wasm exports
    wasm_lib.rdynamic = true;

    const exe = b.addExecutable(.{
        .name = "zig-wasm",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .main_pkg_path = std.build.LazyPath.relative("."),
    });

    const esbuild = b.addSystemCommand(&[_][]const u8{
        "npx",
        "esbuild",
        "src/script.ts",
        "--bundle",
        "--minify",
        "--outfile=zig-out/embed/script.js",
    });
    wasm_lib.step.dependOn(&esbuild.step);

    const tailwind = b.addSystemCommand(&[_][]const u8{
        "npx",
        "tailwindcss",
        "-i",
        "src/style.css",
        "--minify",
        "-o",
        "zig-out/embed/style.css",
    });
    wasm_lib.step.dependOn(&tailwind.step);

    exe.step.dependOn(&wasm_lib.step);

    b.installArtifact(exe);
    b.installArtifact(wasm_lib);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run tests");

    inline for (.{ "src/wasm.zig", "src/main.zig" }) |path| {
        const tests = b.addTest(.{
            .root_source_file = .{ .path = path },
            .target = target,
            .optimize = optimize,
        });

        const run_tests = b.addRunArtifact(tests);

        test_step.dependOn(&run_tests.step);
    }
}
