const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create executable
    const exe = b.addExecutable(.{
        .name = "lemongb",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    b.installArtifact(exe);

    // run step
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    // pass in arguments
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // tests
    const cpu_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/core/cpu_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // test for the executable
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_cpu_tests = b.addRunArtifact(cpu_tests);

    const run_exe_tests = b.addRunArtifact(exe_tests);

    // test step
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_cpu_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
