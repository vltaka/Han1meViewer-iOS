# Following grid viewport-lazy performance fix

## User Input

Original:

```text
继续处理上一个会话出现的问题
session-752119bd-694e-4072-b6e4-8fade5d21d71
切换卡顿，会出现没反应，切换后滑动也卡顿
```

English translation:

```text
Continue addressing the issue from session-752119bd-694e-4072-b6e4-8fade5d21d71.
Switching layouts stutters or becomes unresponsive, and scrolling after switching also stutters.
```

## Change and reason

- Changed `iosApp/Features/Following/FollowingView.swift`: the list keeps individual native rows; the video grid now lives in its own ScrollView / LazyVStack / LazyVGrid hierarchy, not a self-sizing List cell.
- The former List row could measure the full video grid, instantiate offscreen images, and make the final-card / footer pagination triggers run too early. This is a code-level explanation, not an Instruments measurement.
- Kept the footer in the lazy vertical stack. Preserved refresh, empty/error UI, stable video IDs, pagination guards, stored layout/column keys, author navigation and video navigation.
- Made the collapsed author strip a bounded-height LazyHStack rather than eagerly creating every avatar.
- Removed the animated author expand/collapse transaction that reflowed the entire page; compute the quantized image resize width once before building cards.
- Kept Nuke caching and width quantization unchanged: different displayed sizes legitimately need different processed thumbnails. No global cache clearing, eager prefetch, or arbitrary delay was added.

## Verification and limits

- Reviewed the 19.88-second iPad recording via sampled frames; the recording shows layout changes, placeholders, and subsequent scrolling. Touch intent, main-thread duration, actual FPS and exact stall duration cannot be proven from these sampled frames.
- Local Python source-structure guards passed (7 checks), and the guards reject the pre-fix revision. Independent read-only review found no code-level blocker; it also confirmed the existing pagination state guards serialize the last-card/footer triggers. These are regression guards for the layout shape, not runtime SwiftUI performance tests.
- This iPad environment cannot run swiftc / Xcode or Instruments. Full native compile is delegated to the existing PR macOS CI; device acceptance still requires installing the new artifact.
- Device acceptance: cold/warm list ↔ grid switching, rapid 1–6 column changes, several pages of scrolling, no pagination loop while idle, refresh, expand/collapse authors, open/return from author/video, iPad rotation, and retained preferences after relaunch.
- Switching List ↔ ScrollView recreates the scroll container and may reset its position; restoring scroll offsets is not part of this fix. A 1-column layout may legitimately fetch additional pages to fill a large viewport only when its end is reached.

## Mistakes / failed attempts

- The previous session identified the nested List/grid risk but did not fix it or inspect the recording successfully.
- This session's first review delegation used empty model-route fields and was rejected without running a child; the corrected delegation started normally.
- The previous local worktree had a modified log and a commit divergent from the current PR head. It was left untouched. This change is in a separate worktree based on PR head d3e3fca, with no force-push or overwrite of those local edits.
