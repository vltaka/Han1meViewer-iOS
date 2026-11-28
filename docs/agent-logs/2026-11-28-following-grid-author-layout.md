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

## Why

The list remains the default and is still available. The new settings are scoped independently so the Following grid and author page do not alter the home or other grid layouts.

## Failed attempts

- An exploratory pull-request file lookup was rejected because it used a placeholder pull-request number. No repository state was changed by that lookup.

## Verification

- Reviewed the implementation paths and storage keys for separation between Following, author, home, and Show More layouts.
- No local Xcode build or runtime UI test was available during this change; check the branch's macOS CI before merging.

## Known limits / follow-up

- Following's grid is currently landscape-cover based; users can adjust its column count, while aspect-ratio control is intentionally added only to author pages as requested.
