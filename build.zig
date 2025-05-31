const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dmslite = b.createModule(.{
        .root_source_file = b.path("src/dmslite.zig"),
        .target = target,
        .optimize = optimize,
    });

    if(b.pkg_hash.len == 0){
        const exe_mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .optimize = optimize,
            .target = target,
        });

        const exe = b.addExecutable(.{
            .name = "dmslite-test",
            .root_module = exe_mod,
        });

        exe_mod.addImport("dmslite", dmslite);

        //exe.root_module.addSystemIncludePath( .{ .cwd_relative = "/usr/include/libdrm" }); //std.fs.cwd().openDir("/usr/include/libdrm", .{ }) });
        //dmslite.linkSystemLibrary2("drm", .{ .use_pkg_config = .force });
        dmslite.addSystemIncludePath( .{ .cwd_relative = "/usr/include/libdrm" });
        exe.linkSystemLibrary("drm");
        exe.linkLibC();

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if(b.args) |args|{
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the test app");
        run_step.dependOn(&run_cmd.step);

        const exe_unit_tests = b.addTest(.{
            .root_module = exe_mod,
        });

        const dms_unit_tests = b.addTest(.{
            .root_module = dmslite,
        });

        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
        const run_dms_unit_tests = b.addRunArtifact(dms_unit_tests);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_exe_unit_tests.step);
        test_step.dependOn(&run_dms_unit_tests.step);
    }
}
