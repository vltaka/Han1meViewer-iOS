# 关注更新与作者网格布局

## User Input

Original:

```text
1、关注更新加个网格，保留现在的列表，设置切换，并且网格下可以调节列数
2、作者里面加个设置可以调节列数和比例
```

English translation:

```text
1. Add a grid option for Following updates while keeping the current list, provide a setting to switch between them, and let users adjust the number of grid columns.
2. Add settings on author pages to adjust the number of columns and the aspect ratio.
```

## Changes

- Added a persistent list/grid display choice for Following updates. The existing list rows remain unchanged; grid cards open the same video detail screen.
- Added an in-grid column-count stepper for Following, with a range of 1–6 columns and persistent storage.
- Added an author-page settings button with independent column-count and cover-aspect-ratio preferences. Changes apply immediately and reset only the author-page preferences.
- Added English, Simplified Chinese, and Traditional Chinese strings for the new controls.
- Extended the macOS cover-sizing check script to cover author preference keys, explicit column counts, and computed cover widths.

## Why

The list remains the default and is still available. The new settings are scoped independently so the Following grid and author page do not alter the home or other grid layouts.

## Failed attempts

- Two exploratory pull-request lookups (files and status) were rejected because they used a placeholder pull-request number; no repository state was changed by those lookups.
- A direct Git push failed authentication in this environment; the final changes are being applied through the connected GitHub integration instead.

## Verification

- Reviewed the implementation paths and storage keys for separation between Following, author, home, and Show More layouts.
- Preserved the original adaptive author grid when the setting is reset or left at Automatic; fixed 1–6 columns are opt-in.
- Made author cover resize requests follow the actual adaptive/fixed cover width even when the aspect ratio remains at its default, preventing blurry large cards.
- Calculated Following grid image requests from the actual viewport and column count, and restricted pagination triggers to the last video in the loaded snapshot.
- Added coverage for the new grid sizing helpers; no local Xcode build or runtime UI test was available. The macOS CI is running on the draft pull request.

## Known limits / follow-up

- Following's grid is currently landscape-cover based; users can adjust its column count, while aspect-ratio control is intentionally added only to author pages as requested.
