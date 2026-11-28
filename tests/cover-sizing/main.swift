import SwiftUI

// Compile this file WITH the production VideoCoverSizing.swift on the macOS
// build runner. These checks exercise the real implementation, not a copy.
var checks = 0

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
}

func close(_ actual: CGFloat, _ expected: CGFloat) -> Bool {
    abs(actual - expected) < 0.0001
}

expect(VideoCoverScope.home.widthKey != VideoCoverSizing.gridColumnCountKey, "Home width and grid column preferences must be independent")
expect(VideoCoverScope.home.aspectRatioKey != VideoCoverScope.homeSection.aspectRatioKey, "Ratio preferences must be independent")
expect(Set([
    VideoCoverScope.home.widthKey, VideoCoverScope.home.aspectRatioKey,
    VideoCoverSizing.gridColumnCountKey, VideoCoverScope.homeSection.aspectRatioKey
]).count == 4, "Each active preference needs its own key")

let landscape = CGFloat(16.0 / 9.0)
let portrait = CGFloat(268.0 / 394.0)
expect(close(VideoCoverSizing.coverWidth(storedWidth: 0, originalWidth: 184, containerWidth: 1024), 184), "Reset must preserve the original home width")
expect(VideoCoverSizing.effectiveGridColumnCount(storedCount: 3, containerWidth: 390, spacing: 10) == 3, "Default phone portrait grid must retain three columns")
expect(VideoCoverSizing.boundedGridColumnCount(0) == 1, "Column count must not fall below one")
expect(VideoCoverSizing.boundedGridColumnCount(99) == 6, "Column count must not exceed six")
expect(close(VideoCoverSizing.coverWidth(storedWidth: 0, originalWidth: 80, containerWidth: 320), 80), "Original narrow portrait covers must not be enlarged on reset")
expect(close(VideoCoverSizing.aspectRatio(storedRatio: 0, originalRatio: portrait), portrait), "Reset must retain the original category ratio")
expect(close(VideoCoverSizing.aspectRatio(storedRatio: 0.1, originalRatio: landscape), 0.5), "Custom ratio must respect the lower bound")
expect(close(VideoCoverSizing.aspectRatio(storedRatio: 10, originalRatio: landscape), 3), "Custom ratio must respect the upper bound")
expect(close(VideoCoverSizing.aspectRatio(storedRatio: .nan, originalRatio: portrait), portrait), "Invalid ratio must fall back to the original")
expect(close(VideoCoverSizing.coverWidth(storedWidth: 1000, originalWidth: 184, containerWidth: 320), 272), "Oversized covers must fit narrow windows")
expect(close(VideoCoverSizing.coverWidth(storedWidth: 1000, originalWidth: 184, containerWidth: 1024), 976), "Wider windows must allow larger covers without rewriting the preference")

let windows: [CGFloat] = [80, 160, 200, 240, 320, 375, 390, 430, 600, 744, 768, 834, 1024, 1194, 1366, 1600]
let storedWidths: [Double] = [0, 1, 95, 96, 184, 320, 1000, 10000, -1, .nan, .infinity]
for window in windows {
    let range = VideoCoverSizing.widthRange(containerWidth: window)
    expect(range.lowerBound <= range.upperBound, "Slider bounds must remain valid")
    for stored in storedWidths {
        let width = VideoCoverSizing.coverWidth(storedWidth: stored, originalWidth: 184, containerWidth: window)
        expect(width.isFinite && width > 0, "Cover width must remain finite and positive")
        expect(width <= VideoCoverSizing.maximumCoverWidth(containerWidth: window), "Cover must stay inside the viewport")
        for spacing in [CGFloat(10), CGFloat(12)] {
            for requestedCount in VideoCoverSizing.gridColumnCountRange {
                let count = VideoCoverSizing.effectiveGridColumnCount(
                    storedCount: requestedCount,
                    containerWidth: window,
                    spacing: spacing
                )
                let columns = VideoCoverSizing.gridColumns(
                    columnCount: requestedCount,
                    containerWidth: window,
                    spacing: spacing
                )
                expect(columns.count == count, "Grid layout must honor the effective column count")
                expect(count >= 1 && count <= requestedCount, "Grid must clamp to at least one fitting column")

                let coverWidth = VideoCoverSizing.gridCoverWidth(
                    columnCount: requestedCount,
                    containerWidth: window,
                    spacing: spacing
                )
                expect(coverWidth.isFinite && coverWidth > 0, "Flexible cover width must remain finite and positive")
                let totalWidth = (coverWidth + VideoCoverSizing.cardHorizontalPadding) * CGFloat(count)
                    + CGFloat(count - 1) * spacing
                let availableWidth = max(1, window - VideoCoverSizing.pageHorizontalPadding)
                expect(close(totalWidth, availableWidth), "Flexible grid columns must use the full available width")
            }
        }
        for ratio in [CGFloat(0.5), portrait, 1, landscape, 3] {
            let resize = VideoCoverSizing.imageResizeWidth(coverWidth: width, ratio: ratio, originalRatio: landscape)
            expect(resize.isFinite && resize >= 128 && resize <= 1024, "Resize requests must remain bounded")
            expect(close((resize / 64).rounded(), resize / 64), "Resize requests must reuse size buckets")
        }
    }
}

expect(VideoCoverSizing.effectiveGridColumnCount(storedCount: 6, containerWidth: 390, spacing: 10) == 3, "Narrow phone layouts must cap columns to a usable count")
expect(VideoCoverSizing.gridColumns(columnCount: 3, containerWidth: 1225, spacing: 12).count == 3, "Tablet grid must honor three selected columns")
expect(VideoCoverSizing.gridColumns(columnCount: 4, containerWidth: 1225, spacing: 12).count == 4, "Tablet grid must honor four selected columns")
expect(
    VideoCoverSizing.gridCoverWidth(columnCount: 4, containerWidth: 1225, spacing: 12)
        < VideoCoverSizing.gridCoverWidth(columnCount: 3, containerWidth: 1225, spacing: 12),
    "More columns must reduce each cover width while filling the same row"
)
print("Cover grid checks passed: \(checks)")
