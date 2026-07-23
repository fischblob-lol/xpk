const std = @import("std");


// do not recommend building with release, as this is mostly io stuff and moving files, so making the binary smaller is the better choice
pub fn build(b: *std.Build) void {
    const release = b.option(bool, "release", "strip debug + optimize") orelse false;
    const small = b.option(bool, "small", "strip debug + make binary smaller") orelse false;
   
    const linux = b.option(bool, "linux", "cross compile to linux based systems") orelse false;

    
    const target = if (linux) // also on arg
    b.resolveTargetQuery(.{
        .cpu_arch = .x86_64, // for linux
        .os_tag = .linux,
    })
    else
    b.standardTargetOptions(.{});
    
    const utils = b.createModule(.{
        .root_source_file = b.path("src/utils/utils.zig"),
    });
    const exe = b.addExecutable(.{
        .name = "xpk",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .strip = release or small,
            .optimize = if (release) .ReleaseFast else if (small) .ReleaseSmall else .Debug,
        }),
    });

    const parser = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/parsers/parser_test.zig"),
            .target = target,
            .optimize = if (release) .ReleaseFast else if (small) .ReleaseSmall else .Debug,
        })
       
    });

    const hasher = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/security/hasher_test.zig"),
            .target = target,
            .optimize = if (release) .ReleaseFast else if (small) .ReleaseSmall else .Debug,
        })
    });
    
    const repoparse = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/parsers/repos/repos_test.zig"),
            .target = target,
            .optimize = if (release) .ReleaseFast else if (small) .ReleaseSmall else .Debug,
        })
    });

    const keyringparse = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/parsers/keyring/keyring_test.zig"),
            .target = target,
            .optimize = if (release) .ReleaseFast else if (small) .ReleaseSmall else .Debug,
        })
    });


    const automl = b.dependency("automl", .{
        .target = target,
    });


    
    const parsertests = b.addRunArtifact(parser);
    const hashertests = b.addRunArtifact(hasher);
    const repotests = b.addRunArtifact(repoparse);
    const keyringtests = b.addRunArtifact(keyringparse);
    const tests = b.step("test", "run parser tests"); // an arg
    tests.dependOn(&hashertests.step);
    tests.dependOn(&parsertests.step);
    tests.dependOn(&repotests.step);
    tests.dependOn(&keyringtests.step);

    exe.root_module.addImport("automl", automl.module("automl"));
    exe.root_module.addImport("utils", utils);
    b.installArtifact(exe);
}