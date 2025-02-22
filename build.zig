const std = @import ("std");
const zig_version = @import ("builtin").zig_version;

const glfw = @import ("build/glfw.zig");
const vk = @import ("build/vk.zig");
const imgui = @import ("build/imgui.zig");
const shaders = @import ("build/shaders.zig");

const utils = @import ("build/utils.zig");
const Options = utils.Options;
const Package = utils.Package;
const Profile = utils.Profile;
const zon = utils.zon;

pub fn build (builder: *std.Build) !void
{
  try requirements ();
  const profile = try parse_options (builder);
  const shaders_module = try run_shaders_compiler (builder, &profile);
  try run_exe (builder, &profile, shaders_module);
  try run_test (builder, &profile);
}

fn requirements () !void
{
  if (zig_version.order (
    try std.SemanticVersion.parse (zon.min_zig_version)) == .lt)
      std.debug.panic ("{s} needs at least Zig {s} to be build",
        .{ zon.name, zon.min_zig_version, });
}

fn turbo (profile: *Profile) !void
{
  // Keep this for debug purpose
  // profile.optimize = .Debug;
  // profile.variables.addOption (u8, "log_level", 2);
  profile.optimize = .ReleaseFast;
  profile.variables.addOption ([] const u8, "log_dir", "");
  profile.variables.addOption (u8, "log_level", 0);
  profile.variables.addOption ([] const [] const [] const u8,
    "vk_optional_extensions", &.{});
  profile.compile_options = .{
    .optimization = .Performance,
    .vulkan_env_version = std.meta.stringToEnum (
      shaders.Options.VulkanEnvVersion, profile.options.vkminor).?,
  };
}

fn dev (builder: *std.Build, profile: *Profile) !void
{
  const log_dir = "log";

  // Make log directory if not present only in dev mode
  builder.build_root.handle.makeDir (log_dir) catch |err|
  {
    // Do not return error if log directory already exists
    if (err != std.fs.File.OpenError.PathAlreadyExists) return err;
  };

  profile.optimize = .Debug;
  profile.variables.addOption ([] const u8, "log_dir",
    try builder.build_root.join (builder.allocator, &.{ log_dir, }));
  profile.variables.addOption (u8, "log_level", 2);
  profile.variables.addOption ([] const [] const [] const u8,
    "vk_optional_extensions", &.{
      &.{ "EXT", "DEVICE_ADDRESS_BINDING_REPORT", },
      &.{ "EXT", "VALIDATION_FEATURES", },
      &.{ "KHR", "SHADER_NON_SEMANTIC_INFO", },
    });
  profile.compile_options = .{
    .optimization = .Zero,
    .vulkan_env_version = std.meta.stringToEnum (
      shaders.Options.VulkanEnvVersion, profile.options.vkminor).?,
  };
}

fn default (builder: *std.Build, profile: *Profile) !void
{
  profile.optimize = builder.standardOptimizeOption (.{});
  profile.variables.addOption ([] const u8, "log_dir", profile.options.logdir);
  profile.variables.addOption (u8, "log_level", 1);
  profile.variables.addOption ([] const [] const [] const u8,
    "vk_optional_extensions", &.{
      &.{ "EXT", "DEVICE_ADDRESS_BINDING_REPORT", },
    });
  profile.compile_options = .{
    .optimization = .Zero,
    .vulkan_env_version = std.meta.stringToEnum (
      shaders.Options.VulkanEnvVersion,
      profile.options.vkminor).?,
  };
}

fn parse_options (builder: *std.Build) !Profile
{
  const options = Options {
    .dev = builder.option (bool, std.meta.fieldInfo (Options, .dev).name,
        "Build " ++ zon.name ++ " with full logging features. Default: " ++
        (if (@field (Options.default, std.meta.fieldInfo (Options, .dev).name))
          "enabled" else "disabled") ++ ".")
      orelse @field (Options.default, std.meta.fieldInfo (Options, .dev).name),
    .turbo = builder.option (bool, std.meta.fieldInfo (Options, .turbo).name,
        "Build " ++ zon.name ++ " with optimized features. Default: " ++
        (if (@field (Options.default, std.meta.fieldInfo (Options, .turbo).name))
          "enabled" else "disabled") ++ ".")
      orelse @field (Options.default, std.meta.fieldInfo (Options, .turbo).name),
    .logdir = builder.option ([] const u8,
        std.meta.fieldInfo (Options, .logdir).name,
        "Absolute path to log directory. If not specified, logs are not registered in a file.")
      orelse @field (Options.default, std.meta.fieldInfo (Options, .logdir).name),
    .vkminor = builder.option ([] const u8,
        std.meta.fieldInfo (Options, .vkminor).name,
        "Vulkan minor version to use: Possible values: 0, 1, 2 or 3. Default value: " ++
        @field (Options.default, std.meta.fieldInfo (Options, .vkminor).name) ++ ".")
      orelse @field (Options.default, std.meta.fieldInfo (Options, .vkminor).name),
  };

  _ = std.fmt.parseInt (u2, options.vkminor, 10) catch
    std.debug.panic ("-D{s} value should be 0, 1, 2 or 3",
      .{ std.meta.fieldInfo (Options, .vkminor).name, });

  if (options.turbo and options.dev)
    std.debug.panic ("-D{s} and -D{s} can not be used together",
      .{ std.meta.fieldInfo (Options, .turbo).name,
         std.meta.fieldInfo (Options, .dev).name, })
  else if (options.turbo and options.logdir.len > 0)
    std.debug.panic ("-D{s} and -D{s} can not be used together",
      .{ std.meta.fieldInfo (Options, .turbo).name,
         std.meta.fieldInfo (Options, .logdir).name, });

  var profile: Profile = undefined;
  profile.target = builder.standardTargetOptions (.{});
  profile.options = options;
  profile.variables = builder.addOptions ();
  profile.variables.addOption ([] const u8,
    std.meta.fieldInfo (@TypeOf (zon), .name).name, zon.name);
  profile.variables.addOption ([] const u8,
    std.meta.fieldInfo (@TypeOf (zon), .version).name, zon.version);
  profile.variables.addOption ([] const u8, "vk_minor",
    profile.options.vkminor);

  if (profile.options.turbo) try turbo (&profile)
  else if (profile.options.dev) try dev (builder, &profile)
  else try default (builder, &profile);

  return profile;
}

fn link (builder: *std.Build, profile: *const Profile) !*Package
{
  const cimgui_dep = builder.dependency ("cimgui", .{
    .target = profile.target,
    .optimize = profile.optimize,
    .platform = .GLFW,
    .renderer = .Vulkan,
  });

  const c = try Package.init (builder, profile, "c",
    try builder.build_root.join (builder.allocator,
      &.{ "src", zon.name, "bindings", "raw.zig", }));
  c.link (cimgui_dep.artifact ("cimgui"));

  return c;
}

fn manage_deps (glfw_pkg: *Package, vk_pkg: *Package) !void
{
  try glfw_pkg.get ("window").put (vk_pkg.get ("instance"), .{});
  try glfw_pkg.get ("window").put (vk_pkg.get ("khr").get ("surface"), .{});
  try vk_pkg.put (glfw_pkg.get ("vk"), .{ .pkg_name = "glfw", });
}

fn import (builder: *std.Build, exe: *std.Build.Step.Compile,
  profile: *const Profile, shaders_module: *std.Build.Module) !void
{
  const datetime_dep = builder.dependency ("zig-datetime", .{
    .target = profile.target,
    .optimize = profile.optimize,
  });
  const datetime = datetime_dep.module ("zig-datetime");

  const jdz_dep = builder.dependency ("jdz_allocator", .{
    .target = profile.target,
    .optimize = profile.optimize,
  });
  const jdz = jdz_dep.module ("jdz_allocator");

  const c = try link (builder, profile);
  const glfw_pkg = try glfw.import (builder, profile, c);
  const vk_pkg = try vk.import (builder, profile, c);
  const imgui_pkg = try imgui.import (builder, profile, c, glfw_pkg, vk_pkg);

  try manage_deps (glfw_pkg, vk_pkg);

  const build_options = profile.variables.createModule ();
  const logger = builder.createModule (.{
    .root_source_file = .{ .cwd_relative = try builder.build_root.join (
      builder.allocator, &.{ "src", zon.name, "logger.zig", }), },
    .target = profile.target,
    .optimize = profile.optimize,
  });
  logger.addImport ("build", build_options);
  logger.addImport ("datetime", datetime);
  logger.addImport ("jdz", jdz);

  const instance = builder.createModule (.{
    .root_source_file = .{ .cwd_relative = try builder.build_root.join (
      builder.allocator, &.{ "src", zon.name, "vk", "instance",
        if (profile.options.turbo) "turbo.zig" else "default.zig", }), },
    .target = profile.target,
    .optimize = profile.optimize,
  });
  instance.addImport ("logger", logger);
  instance.addImport ("vk", vk_pkg.module);

  for ([_] struct { name: [] const u8, ptr: *std.Build.Module, } {
    .{ .name = "datetime", .ptr = datetime, },
    .{ .name = "jdz", .ptr = jdz, },
    .{ .name = "shader", .ptr = shaders_module, },
    .{ .name = "glfw", .ptr = glfw_pkg.module, },
    .{ .name = "vk", .ptr = vk_pkg.module, },
    .{ .name = "imgui", .ptr = imgui_pkg.module, },
    .{ .name = "logger", .ptr = logger, },
    .{ .name = "instance", .ptr = instance, },
  }) |module| exe.root_module.addImport (module.name, module.ptr);
}

fn run_shaders_compiler (builder: *std.Build,
  profile: *const Profile) !*std.Build.Module
{
  const shaders_compiler = builder.addExecutable (.{
    .name = "shaders_compiler",
    .root_source_file = .{ .cwd_relative = try builder.build_root.join (
      builder.allocator, &.{ "src", "compiler", "main.zig", }), },
    .target = builder.host,
    .optimize = .Debug,
  });

  const shaderc_dep = builder.dependency ("shaderc", .{
    .target = profile.target,
    .optimize = profile.optimize,
  });

  const c = builder.createModule (.{
    .root_source_file = .{ .cwd_relative = try builder.build_root.join (
      builder.allocator, &.{ "src", "compiler", "bindings", "raw.zig", }), },
    .target = builder.host,
    .optimize = .Debug,
  });
  c.linkLibrary (shaderc_dep.artifact ("shaderc"));

  const shaderc = builder.createModule (.{
    .root_source_file = .{ .cwd_relative = try builder.build_root.join (
      builder.allocator,
      &.{ "src", "compiler", "bindings", "shaderc", "shaderc.zig", }), },
    .target = profile.target,
    .optimize = profile.optimize,
  });
  shaderc.addImport ("c", c);

  shaders_compiler.root_module.addImport ("shaderc", shaderc);

  const install_shaders_compiler =
    builder.addInstallArtifact (shaders_compiler, .{});

  builder.install_tls.step.dependOn (&install_shaders_compiler.step);

  var self_dependency = std.Build.Dependency { .builder = builder, };

  const shaders_module = try shaders.Step.compileModule (
    &self_dependency, profile.compile_options);

  const shaders_compile_step = builder.addRunArtifact (shaders_compiler);

  shaders_compile_step.step.dependOn (&install_shaders_compiler.step);

  return shaders_module;
}

fn run_exe (builder: *std.Build, profile: *const Profile,
  shaders_module: *std.Build.Module) !void
{
  const exe = builder.addExecutable (.{
    .name = zon.name,
    .root_source_file = .{ .cwd_relative = try builder.build_root.join (
      builder.allocator, &.{ "src", zon.name, "main.zig", }), },
    .target = profile.target,
    .optimize = profile.optimize,
  });

  try import (builder, exe, profile, shaders_module);

  builder.installArtifact (exe);

  const run_cmd = builder.addRunArtifact (exe);
  run_cmd.step.dependOn (builder.getInstallStep ());

  const run_step = builder.step ("run", "Run " ++ zon.name);
  run_step.dependOn (&run_cmd.step);
}

fn run_test (builder: *std.Build, profile: *const Profile) !void
{
  const unit_tests = builder.addTest (.{
    .target = profile.target,
    .optimize = profile.optimize,
    .test_runner = .{ .cwd_relative = try builder.build_root.join (builder.allocator,
      &.{ "test", "runner.zig", }), },
    .root_source_file = .{ .cwd_relative = try builder.build_root.join (
      builder.allocator, &.{ "test", "main.zig", }), },
  });
  unit_tests.step.dependOn (builder.getInstallStep ());

  const run_unit_tests = builder.addRunArtifact (unit_tests);

  const test_step = builder.step ("test", "Run tests");
  test_step.dependOn (&run_unit_tests.step);
}
