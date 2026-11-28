import SwiftUI

/// The two entry points intentionally use separate, local display preferences.
enum VideoCoverScope {
    case home
    case homeSection
    case artist

    var widthKey: String? {
        switch self {
        case .home: VideoCoverSizing.homeWidthKey
        case .homeSection: VideoCoverSizing.gridWidthKey
        case .artist: nil
        }
    }

    var aspectRatioKey: String {
        switch self {
        case .home: VideoCoverSizing.homeAspectRatioKey
        case .homeSection: VideoCoverSizing.gridAspectRatioKey
        case .artist: VideoCoverSizing.artistAspectRatioKey
        }
    }

    var columnCountKey: String? {
        switch self {
        case .artist: VideoCoverSizing.artistGridColumnCountKey
        case .home, .homeSection: nil
        }
    }

    var showsCoverWidth: Bool {
        widthKey != nil
    }
}

/// Widths describe the cover itself; videoCardSurface adds 8pt on each side.
/// A stored zero means "use the original layout", not a zero-sized cover.
enum VideoCoverSizing {
    static let homeWidthKey = "home_video_cover_width"
    static let homeAspectRatioKey = "home_video_cover_aspect_ratio"
    static let gridWidthKey = "home_section_cover_width"
    static let gridAspectRatioKey = "home_section_cover_aspect_ratio"
    static let artistAspectRatioKey = "artist_video_cover_aspect_ratio"
    static let artistGridColumnCountKey = "artist_video_grid_columns"
    static let automatic: Double = 0
    static let defaultHomeWidth: CGFloat = 184
    static let defaultArtistGridColumnCount = 3
    static let minimumGridColumnCount = 1
    static let maximumGridColumnCount = 6
    static let minimumCoverWidth: CGFloat = 96
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

    /// Mirrors the original grid only to report its current cover width in the
    /// controls. The uncustomized view still uses its original GridItem layout.
    static func originalGridCoverWidth(containerWidth: CGFloat, phonePortrait: Bool) -> CGFloat {
        let available = max(1, containerWidth - pageHorizontalPadding)
        let spacing: CGFloat = phonePortrait ? 10 : gridSpacing
        let count = phonePortrait ? 3 : max(1, Int((available + spacing) / (160 + spacing)))
        return originalGridCoverWidth(containerWidth: containerWidth, columnCount: count, spacing: spacing)
    }

    static func originalGridCoverWidth(
        containerWidth: CGFloat,
        columnCount: Int,
        spacing: CGFloat
    ) -> CGFloat {
        let available = max(1, containerWidth - pageHorizontalPadding)
        let count = min(maximumGridColumnCount, max(minimumGridColumnCount, columnCount))
        let cardWidth = (available - CGFloat(count - 1) * spacing) / CGFloat(count)
        return max(1, cardWidth - cardHorizontalPadding)
    }

    static func flexibleGridColumns(columnCount: Int, spacing: CGFloat) -> [GridItem] {
        let count = min(maximumGridColumnCount, max(minimumGridColumnCount, columnCount))
        return Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: spacing, alignment: .top),
            count: count
        )
    }

    static func gridColumns(coverWidth: CGFloat, containerWidth: CGFloat, spacing: CGFloat) -> [GridItem] {
        let cardWidth = coverWidth + cardHorizontalPadding
        let available = max(1, containerWidth - pageHorizontalPadding)
        let count = max(1, Int((available + spacing) / (cardWidth + spacing)))
        return Array(
            repeating: GridItem(.fixed(cardWidth), spacing: spacing, alignment: .top),
            count: count
        )
    }

    /// Reuse a small number of resize requests while sliders move. Account for
    /// center-cropping a landscape source into a tall cover; do not multiply by
    /// screen scale here (Nuke's processor already works in points).
    static func imageResizeWidth(coverWidth: CGFloat, ratio: CGFloat, originalRatio: CGFloat) -> CGFloat {
        let required = coverWidth * max(1, originalRatio / ratio)
        return min(1024, max(128, (required / 64).rounded(.up) * 64))
    }
}
