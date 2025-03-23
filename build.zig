const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    const is_root = b.pkg_hash.len == 0;

    const target = if (is_root) b.standardTargetOptions(.{}) else null;
    const optimize = if (is_root) b.standardOptimizeOption(.{}) else null;
    const filters = if (is_root) b.option([]const []const u8, "filter", "Filter to apply to the unit test") else null;
    const no_bin = if (is_root) b.option(bool, "no-bin", "Don't install any of the binaries implied by the specified steps") orelse false else true;
    const no_run = if (is_root) b.option(bool, "no-run", "Don't run any of the executables implied by the specified steps") orelse false else true;

    const install_step = b.getInstallStep();
    const unit_test_step = b.step("unit-test", "Run unit tests.");

    {
        const test_step = b.step("test", "Run all tests.");
        test_step.dependOn(unit_test_step);
    }

    const main_mod = b.addModule("ncs", .{
        .root_source_file = b.path("input-lock.zig"),
        .target = target,
        .optimize = optimize,
    });

    const unit_test_exe = b.addTest(.{
        .name = "unit-test",
        .root_module = main_mod,
        .filters = filters orelse &.{},
    });

    if (!no_bin) {
        const unit_test_install = b.addInstallArtifact(unit_test_exe, .{});
        unit_test_step.dependOn(&unit_test_install.step);
        install_step.dependOn(install_step);
    }

    if (!no_run) {
        const unit_test_run = b.addRunArtifact(unit_test_exe);
        unit_test_step.dependOn(&unit_test_run.step);
    }
}
