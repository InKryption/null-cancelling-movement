const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    _ = b.addModule("ncs", Build.CreateModuleOptions{
        .source_file = b.path("input-lock.zig"),
    });
}
