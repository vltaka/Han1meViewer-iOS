import SwiftUI

/// The two entry points intentionally use separate, local display preferences.
enum VideoCoverScope {
    case home
    case homeSection

    var widthKey: String {
        switch self {
        case .home: VideoCoverSizing.homeWidthKey
        case .homeSection: VideoCoverSizing.gridWidthKey
        }
    }

    var aspectRatioKey: String {
        switch self {
        case .home: VideoCoverSizing.homeAspectRatioKey
        case .homeSection: VideoCoverSizing.gridAspectRatioKey
        }
    }

    var usesColumnCountControl: Bool {
        if case .homeSection = self { return true }
        return false
    }
}

/// Widths describe the cover itself; videoCardSurface adds 8pt on each side.
/// A stored zero means "use the original layout", not a zero-sized cover.
enum VideoCoverSizing {
    static let homeWidthKey = "home_video_cover_width"
    static let homeAspectRatioKey = "home_video_cover_aspect_ratio"
    static let gridWidthKey = "home_section_cover_width" // Legacy preference; no longer controls the grid.
    static let gridColumnCountKey = "home_section_grid_column_count"
    static let gridAspectRatioKey = "home_section_cover_aspect_ratio"
    static let automatic: Double = 0
    static let defaultHomeWidth: CGFloat = 184
    static let minimumCoverWidth: CGFloat = 96
    static let minimumGridCoverWidth: CGFloat = 72
    static let defaultGridColumnCount = 3
    static let gridColumnCountRange = 1...6
    static let aspectRatioRange: ClosedRange<Double> = 0.5...3.0
    static let cardHorizontalPadding: CGFloat = 16
    static let pageHorizontalPadding: CGFloat = 32
    static let gridSpacing: CGFloat = 12

    static func isCustomized(_ value: Double) -> Bool {
        value.isFinite && value > 0
    }

    static func maximumCoverWidth(containerWidth: CGFloat) -> CGFloat {
        guard containerWidth.isFinite else { return defaultHomeWidth }
        return max(1, containerWidth - pageHorizontalPadding - cardHorizontalPadding)
    }

    static func widthRange(containerWidth: CGFloat) -> ClosedRange<Double> {
        let maximum = maximumCoverWidth(containerWidth: containerWidth)
        return Double(min(minimumCoverWidth, maximum))...Double(maximum)
    }

    static func coverWidth(
        storedWidth: Double,
        originalWidth: CGFloat,
        containerWidth: CGFloat
    ) -> CGFloat {
        let maximum = maximumCoverWidth(containerWidth: containerWidth)
        // Preserve the original three-column portrait layout, even where its
        // uncustomized covers are narrower than the slider's minimum.
        guard isCustomized(storedWidth) else { return min(maximum, max(1, originalWidth)) }
        return min(maximum, max(min(minimumCoverWidth, maximum), CGFloat(storedWidth)))
    }

    static func aspectRatio(storedRatio: Double, originalRatio: CGFloat) -> CGFloat {
        guard isCustomized(storedRatio) else { return originalRatio }
        return CGFloat(min(aspectRatioRange.upperBound, max(aspectRatioRange.lowerBound, storedRatio)))
    }

    /// Keep a usable cover width on narrow phone layouts while respecting the
    /// requested column count everywhere else.
    static func effectiveGridColumnCount(
        storedCount: Int,
        containerWidth: CGFloat,
        spacing: CGFloat
    ) -> Int {
        let available = max(1, (containerWidth.isFinite ? containerWidth : defaultHomeWidth) - pageHorizontalPadding)
        let minimumCardWidth = minimumGridCoverWidth + cardHorizontalPadding
        let fittingCount = max(1, Int((available + spacing) / (minimumCardWidth + spacing)))
        let maximum = min(gridColumnCountRange.upperBound, fittingCount)
        return min(maximum, max(gridColumnCountRange.lowerBound, storedCount))
    }

    static func boundedGridColumnCount(_ count: Int) -> Int {
        min(gridColumnCountRange.upperBound, max(gridColumnCountRange.lowerBound, count))
    }

    static func gridColumns(columnCount: Int, containerWidth: CGFloat, spacing: CGFloat) -> [GridItem] {
        let count = effectiveGridColumnCount(
            storedCount: columnCount,
            containerWidth: containerWidth,
            spacing: spacing
        )
        return Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: spacing, alignment: .top),
            count: count
        )
    }

    /// Estimate the cover's actual width inside each evenly distributed card.
    static func gridCoverWidth(columnCount: Int, containerWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let count = effectiveGridColumnCount(
            storedCount: columnCount,
            containerWidth: containerWidth,
            spacing: spacing
        )
        let available = max(1, (containerWidth.isFinite ? containerWidth : defaultHomeWidth) - pageHorizontalPadding)
        let cardWidth = (available - CGFloat(count - 1) * spacing) / CGFloat(count)
        return max(1, cardWidth - cardHorizontalPadding)
    }

    /// Reuse a small number of resize requests while sliders move. Account for
    /// center-cropping a landscape source into a tall cover; do not multiply by
    /// screen scale here (Nuke's processor already works in points).
    static func imageResizeWidth(coverWidth: CGFloat, ratio: CGFloat, originalRatio: CGFloat) -> CGFloat {
        let required = coverWidth * max(1, originalRatio / ratio)
        return min(1024, max(128, (required / 64).rounded(.up) * 64))
    }
}
