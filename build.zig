const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "zig_cam",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "zig_cam",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(.{ .path = "deps/libuvc/include" });
    // exe.addIncludePath(.{ .path = "/usr/include/libusb-1.0" });

    const libuvc = b.addSharedLibrary(.{
        .name = "libuvc",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .target = target,
        .optimize = optimize,
    });

    // libuvc.addIncludePath(.{ .path = "libuvc/include" });
    // libuvc.addIncludePath(.{ .path = "libuvc/include/libuvc" });
    // libuvc.addIncludePath(.{ .path = "/usr/include/opencv4/opencv2" });

    libuvc.addCSourceFiles(.{
        .files = &.{
            // "libuvc/include/libuvc/libuvc.h",
            // "libuvc/include/libuvc/libuvc_internal.h",
            "deps/libuvc/src/ctrl-gen.c",
            "deps/libuvc/src/ctrl.c",
            "deps/libuvc/src/device.c",
            "deps/libuvc/src/diag.c",
            // "libuvc/src/example.c",
            // "libuvc/src/frame-mjpeg.c",
            "deps/libuvc/src/frame.c",
            "deps/libuvc/src/init.c",
            "deps/libuvc/src/misc.c",
            "deps/libuvc/src/stream.c",
            // "libuvc/src/test.c",
        },
    });
    libuvc.linkLibC();
    libuvc.linkSystemLibrary("c");
    // libuvc.linkSystemLibrary("libusb-1.0");
    libuvc.linkSystemLibrary("libuvc");
    libuvc.linkSystemLibrary("opencv4");

    const libpng = b.addSharedLibrary(.{
        .name = "libpng",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .target = target,
        .optimize = optimize,
    });

    libpng.addIncludePath(.{ .path = "libpng" });

    // libuvc.addIncludePath(.{ .path = "libuvc/include/libuvc" });
    // libuvc.addIncludePath(.{ .path = "/usr/include/opencv4/opencv2" });

    libpng.addCSourceFiles(.{
        .files = &.{
            "libpng/png.c",
            "libpng/pngset.c",
            "libpng/pngwrite.c",
        },
    });
    libpng.linkLibC();
    libpng.linkSystemLibrary("c");

    // exe.linkLibrary(libpng);
    exe.linkLibrary(libuvc);

    exe.linkSystemLibrary("c");
    // exe.linkSystemLibrary("libusb");
    exe.linkSystemLibrary("libusb-1.0");
    exe.linkSystemLibrary("libuvc");

    exe.linkLibC();

    exe.addAnonymousModule("zigimg", .{ .source_file = .{ .path = "deps/zigimg/zigimg.zig" } });
    // exe.addCSourceFile(.{ .file = std.build.LazyPath.relative("src/main.c"), .flags = &.{} });
    // exe.linkLibC();

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
