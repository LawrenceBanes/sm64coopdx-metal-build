# SM64CoopDX Metal shader validation fixtures

This public repository contains only independently generated Metal Shading Language (MSL) shader source fixtures and a macOS validation workflow. It does not contain SM64CoopDX source, the Metal renderer implementation, game assets, ROM data, or compiled application binaries.

The fixtures exercise representative renderer adapter output: textureless, texture tile 0, texture tile 1, and a two-cycle alpha/fog/light-map/world-flag path. They are compiled against Apple's iPhoneOS Metal SDK by GitHub Actions on a standard macOS runner. A successful fixture compile validates MSL syntax and entry-point compilation only; it does not validate the app backend, pipeline binding compatibility, rendering, iOS linking, or device output.

## Source and rights boundary

SM64CoopDX's iOS repository currently has no identified repository license or root `LICENSE`/`COPYING` file. Its source and game assets are therefore not reproduced here. The fixtures were generated from the independently authored adapter in the separate development checkout. The full application source changes and patch overlay remain outside this public repository pending a compatible source license or explicit authorization.

No game, ROM, Nintendo-derived asset, or third-party binary is included. The MIT license in this repository applies only to the fixtures, workflow, and documentation stored here.
