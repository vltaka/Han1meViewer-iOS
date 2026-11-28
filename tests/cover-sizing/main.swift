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

expect(VideoCoverScope.home.widthKey != VideoCoverScope.homeSection.widthKey, "Width preferences must be independent")
expect(VideoCoverScope.home.aspectRatioKey != VideoCoverScope.homeSection.aspectRatioKey, "Ratio preferences must be independent")
expect(Set([
    VideoCoverScope.home.widthKey, VideoCoverScope.home.aspectRatioKey,
    VideoCoverScope.homeSection.widthKey, VideoCoverScope.homeSection.aspectRatioKey
]).count == 4, "Each preference needs its own key")
expect(VideoCoverScope.artist.widthKey == nil, "Artist preferences must not reuse a cover-width key")
expect(VideoCoverScope.artist.aspectRatioKey == VideoCoverSizing.artistAspectRatioKey, "Artist ratio must have a dedicated key")
expect(VideoCoverScope.artist.columnCountKey == VideoCoverSizing.artistGridColumnCountKey, "Artist columns must have a dedicated key")
expect(VideoCoverScope.artist.aspectRatioKey != VideoCoverScope.homeSection.aspectRatioKey, "Artist ratio must be independent of Show More")
expect(VideoCoverSizing.defaultArtistGridColumnCount == VideoCoverSizing.automaticGridColumnCount, "Artist default must preserve adaptive columns")
expect(VideoCoverSizing.flexibleGridColumns(columnCount: 4, spacing: 12).count == 4, "Explicit grid columns must be honored")
expect(VideoCoverSizing.flexibleGridColumns(columnCount: 99, spacing: 12).count == VideoCoverSizing.maximumGridColumnCount, "Grid column count must be bounded")
expect(close(
    VideoCoverSizing.originalGridCoverWidth(containerWidth: 390, columnCount: 3, spacing: 12),
    (390 - 32 - 24) / 3 - 16
), "Artist cover width must match the chosen column count")

let landscape = CGFloat(16.0 / 9.0)
let portrait = CGFloat(268.0 / 394.0)
expect(close(VideoCoverSizing.coverWidth(storedWidth: 0, originalWidth: 184, containerWidth: 1024), 184), "Reset must preserve the original home width")
expect(close(VideoCoverSizing.originalGridCoverWidth(containerWidth: 390, phonePortrait: true), (390 - 32 - 20) / 3 - 16), "Default phone portrait grid must retain three columns")
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
            let columns = VideoCoverSizing.gridColumns(coverWidth: width, containerWidth: window, spacing: spacing)
            expect(!columns.isEmpty, "Grid must retain at least one column")
            var total: CGFloat = CGFloat(columns.count - 1) * spacing
            for column in columns {
                guard case .fixed(let cardWidth) = column.size else {
                    preconditionFailure("Customized columns must honor the chosen width")
                }
                total += cardWidth
                expect(close(cardWidth - VideoCoverSizing.cardHorizontalPadding, width), "Card padding must not change the requested cover width")
            }
            expect(total <= max(1, window - VideoCoverSizing.pageHorizontalPadding) + 0.0001, "Grid columns must not overflow")
        }
        for ratio in [CGFloat(0.5), portrait, 1, landscape, 3] {
            let resize = VideoCoverSizing.imageResizeWidth(coverWidth: width, ratio: ratio, originalRatio: landscape)
            expect(resize.isFinite && resize >= 128 && resize <= 1024, "Resize requests must remain bounded")
            expect(close((resize / 64).rounded(), resize / 64), "Resize requests must reuse size buckets")
        }
    }
}

let phoneWidth = VideoCoverSizing.coverWidth(storedWidth: 96, originalWidth: 96, containerWidth: 390)
expect(VideoCoverSizing.gridColumns(coverWidth: phoneWidth, containerWidth: 390, spacing: 10).count == 3, "Small customized portrait covers must still fit three phone columns")
print("Cover sizing checks passed: \(checks)")
