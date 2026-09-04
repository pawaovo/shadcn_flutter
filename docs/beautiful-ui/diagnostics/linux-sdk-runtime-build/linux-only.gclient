# Standard pinned Flutter checkout layout, with documented platform switches.
# Versions and dependency entries remain those in the original pinned DEPS.
solutions = [
  {
    "name": ".",
    "url": "https://github.com/flutter/flutter.git",
    "managed": False,
    "deps_file": "DEPS",
    "custom_deps": {},
    "safesync_url": "",
    "custom_vars": {
      "download_android_deps": False,
      "download_jdk": False,
      "download_windows_deps": False,
      "download_linux_deps": True,
      "download_fuchsia_deps": False,
      "download_fuchsia_sdk": False,
      "run_fuchsia_emu": False,
      "download_emsdk": False,
      "download_esbuild": False,
      "download_dart_sdk": True,
      "setup_githooks": False,
      "use_rbe": False,
    },
  },
]
