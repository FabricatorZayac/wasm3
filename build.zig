const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .name = "m3",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    lib.root_module.sanitize_c = .off;
    lib.root_module.addCMacro("d_m3HasTracer", "1");

    if (lib.rootModuleTarget().cpu.arch.isWasm() and lib.rootModuleTarget().os.tag == .wasi) {
        lib.root_module.addCMacro("d_m3HasWASI", "1");
        lib.root_module.linkSystemLibrary("wasi-emulated-process-clocks", .{});
    }
    lib.root_module.addIncludePath(b.path("source"));
    lib.root_module.addCSourceFiles(.{
        .root = b.path("source/"),
        .files = source_files,
        .flags = if (lib.rootModuleTarget().cpu.arch.isWasm())
            &cflags ++ [_][]const u8{
                "-Xclang",
                "-target-feature",
                "-Xclang",
                "+tail-call",
            }
        else
            &cflags,
    });
    lib.root_module.linkSystemLibrary("m", .{});

    for (headers) |header| lib.installHeader(b.path("source/").path(b, header), header);

    b.installArtifact(lib);

    const wasm3 = b.addExecutable(.{
        .name = "wasm3",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });
    wasm3.root_module.addCSourceFile(.{
        .file = .{ .cwd_relative = "platforms/app/main.c" },
        .flags = &cflags,
    });

    wasm3.root_module.linkLibrary(lib);
    b.installArtifact(wasm3);
}

pub const source_files: []const []const u8 = &.{
    "m3_api_libc.c",
    "extensions/m3_extensions.c",
    "m3_api_meta_wasi.c",
    "m3_api_tracer.c",
    "m3_api_uvwasi.c",
    "m3_api_wasi.c",
    "m3_bind.c",
    "m3_code.c",
    "m3_compile.c",
    "m3_core.c",
    "m3_env.c",
    "m3_exec.c",
    "m3_function.c",
    "m3_info.c",
    "m3_module.c",
    "m3_parse.c",
};

pub const headers: []const []const u8 = &.{
    "m3_exception.h",
    "m3_math_utils.h",
    "m3_api_wasi.h",
    "m3_core.h",
    "m3_config.h",
    "m3_exec_defs.h",
    "m3_env.h",
    "m3_info.h",
    "m3_config_platforms.h",
    "m3_bind.h",
    "m3_code.h",
    "m3_compile.h",
    "wasm3.h",
    "m3_function.h",
    "m3_api_libc.h",
    "m3_exec.h",
    "wasm3_defs.h",
    "extra/fib32_tail.wasm.h",
    "extra/fib64.wasm.h",
    "extra/coremark_minimal.wasm.h",
    "extra/fib32.wasm.h",
    "extra/wasi_core.h",
    "extensions/wasm3_ext.h",
    "m3_api_tracer.h",
};

const cflags = [_][]const u8{
    "-Wall",
    "-Wextra",
    "-Wpedantic",
    "-Wparentheses",
    "-Wundef",
    "-Wpointer-arith",
    "-Wstrict-aliasing=2",
    "-std=gnu11",
};
