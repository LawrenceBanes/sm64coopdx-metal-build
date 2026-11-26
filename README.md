# SM64CoopDX Metal shader validation fixtures

This public repository contains independently authored Metal adapter source, minimal mock engine interface declarations, generated Metal Shading Language (MSL) fixtures, and a macOS validation workflow. It does not contain SM64CoopDX engine implementation, game assets, ROM data, or a compiled application.

The fixtures exercise representative renderer adapter output: textureless, texture tile 0, texture tile 1, and a two-cycle alpha/fog/light-map/world-flag path. CI compiles the authored Objective-C Metal backend and its C shader generator against Apple's iPhoneOS SDK using local mock declarations for CoopDX interfaces, then compiles the MSL fixtures. This catches Apple compiler and ARM64 object-generation issues in those components. Mock-interface compilation does not prove ABI compatibility with the full engine, app linking, rendering, or device output.

## Source and rights boundary

SM64CoopDX's iOS repository currently has no identified repository license or root `LICENSE`/`COPYING` file. Its engine source and game assets are therefore not reproduced here. The adapter files under `backend/` were first added as new files by the integration work (not copied from the earlier `sm64ios-metal` repository); the fixture shader source was emitted by that adapter. The `stubs/` files are minimal test contracts written for this compile harness, not copies of engine headers. The full application source changes and patch overlay remain outside this public repository pending a compatible source license or explicit authorization.

No game, ROM, Nintendo-derived asset, or third-party binary is included in Git. The MIT license in this repository applies only to its independently authored adapter files, mock interface stubs, fixtures, workflow, and documentation. CI fetches the pinned SDL 2.32.10 source from the official release, builds an iPhoneOS ARM64 static library, and includes SDL's upstream `LICENSE.txt` with that build artifact. SDL source itself is not committed.

## Previous Apple compiler run

Workflow [45738609822](https://github.com/LawrenceBanes/sm64coopdx-metal-build/actions/runs/45738609822) passed on macOS 15.8.2 ARM64 with Xcode 16.4 (build 16F6) and iPhoneOS SDK 18.5. Its four fixture sources compiled with Apple's `metal -c`. The uploaded `.air` artifact is available [here](https://github.com/LawrenceBanes/sm64coopdx-metal-build/actions/runs/45738609822/artifacts/15080650158); size 22,327 bytes and archive SHA-256 `e361ea24ccacb3df36d2a9fcde15cb29a82599e92fd7a083c56a1056aa558133`.

The expanded workflow adds compilation of the isolated adapter and SDL layer helper as iPhoneOS ARM64 objects, a contract-only stub link of the Metal backend against Apple frameworks, an SDL2 ARM64 library build, and additional generated MSL cases. These are component checks and do not compile/link the complete app or validate runtime behavior. Results from that expanded workflow are not yet available; no iPhone runtime result is implied.
