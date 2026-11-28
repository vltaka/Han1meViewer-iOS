# Run Following layout guards in native PR CI

## User Input

Original: “继续处理上一个会话出现的问题 … 切换卡顿，会出现没反应，切换后滑动也卡顿”

English translation: “Continue fixing the previous session's issue: layout switching and subsequent scrolling stutter or become unresponsive.”

## Change / reason

Attempted to add the seven Python Following layout source-structure checks before the existing cover-sizing check in `.github/workflows/ios-app-build.yml`. The bulk GitHub write containing the workflow was rejected with `Forbidden: insufficient scopes`. The single-file contents API accepts ordinary source/test writes. The workflow edit was reverted locally and is NOT part of the remote fix; no attempt was made to obtain a broader token or change connector permissions. Run `python3 tests/following-layout/test_structure.py` manually for now. The existing PR workflow still compiles the fixed Swift source and runs shared JVM and cover-sizing checks.

## Verification / mistakes / limits

The Python command passes locally. No local native build is possible on this iPad. The source checks are not FPS/UI benchmarks. The relevant macOS CI must pass for the new PR head before this revision is described as build-verified; real-device scroll and switching acceptance is separate. No workflow permissions, secrets, branch triggers or unrelated release jobs were changed.
