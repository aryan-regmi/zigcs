const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "Zigcs",
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    // Export zigcs as a module
    const zigcs_module = b.addModule(
        "zigcs",
        .{
            .source_file = .{ .path = "src/lib.zig" },
            .dependencies = &.{},
        },
    );

    // ============================TESTS================================
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    run_unit_tests.has_side_effects = true; // Force recompile
    const unit_test_step = b.step("unit", "Run library unit tests");
    unit_test_step.dependOn(&run_unit_tests.step);

    // Create step for integration testing.
    const integration_tests = b.addTest(.{
        .root_source_file = .{ .path = "tests.zig" },
        .target = target,
        .optimize = optimize,
    });
    integration_tests.addModule("zigcs", zigcs_module);
    const run_integration_tests = b.addRunArtifact(integration_tests);
    run_integration_tests.has_side_effects = true; // Force recompile
    const integration_tests_step = b.step("test", "Run integration tests");
    integration_tests_step.dependOn(&run_integration_tests.step);
}
