import SwiftUI
import Han1meShared

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// User-customised home-section ordering. Stored as a comma-separated
    /// list of section keys in NSUserDefaults under `home_section_order`.
    /// Edited by HomeSectionOrderView (设置 → 首页栏目排序). Empty = use
    /// the order the server returned. Sections present in the snapshot
    /// but absent from the saved order are appended at the end (so newly
    /// added server sections still surface).
    @AppStorage("home_section_order") private var homeSectionOrderRaw: String = ""

    /// Comma-separated list of section keys the user has hidden from the
    /// home page. Defaults to `aiGenerated` so a fresh install hides AI-
    /// generated anime out of the box; the user can drag it into "已显示"
    /// in the section-order page to bring it back.
    @AppStorage("home_section_hidden") private var homeSectionHiddenRaw: String = "aiGenerated"

    /// Vertical scroll offset of the loaded home content, used to fade the
    /// self-drawn large "首页" title into a compact inline header on scroll.
    /// See docs/known-issues/nav-bar-title-crossfade-over-player.md for why
    /// the title is drawn manually instead of via .navigationTitle.
    @State private var scrollOffset: CGFloat = 0
    @State private var showingCoverSettings = false

    init(environment: SharedAppEnvironment) {
        self.videoFeature = environment.videoFeature()
        self.commentFeature = environment.commentFeature()
        _viewModel = StateObject(wrappedValue: HomeViewModel(homeFeature: environment.homeFeature()))
    }

    var body: some View {
        CompatibleNavigationStack {
            content
                // System nav bar is hidden so it carries no "首页" title that
                // could cross-fade on top of the full-bleed video player while
                // popping back from VideoDetailView. The large title is drawn
                // inside the content instead (option 3 in the known-issue doc).
                .toolbar(.hidden, for: .navigationBar)
                .logScreen("Home")
                .task {
                    viewModel.loadIfNeeded()
                }
                .refreshable {
                    await viewModel.refresh()
                }
        }
    }

    /// 0 while the large title is fully visible, ramping to 1 once the user
    /// has scrolled ~36pt — the crossover point where the large title has
    /// left and the compact inline title takes over.
    private var inlineTitleProgress: Double {
        min(1, max(0, Double(scrollOffset) / 36))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message, let isIPBlocked):
            GeometryReader { proxy in
                ScrollView {
                VStack(spacing: 12) {
                    Image(systemName: isIPBlocked ? "network.badge.shield.half.filled" : "wifi.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Group {
                        if isIPBlocked {
                            Text("当前网络已被站点封锁")
                        } else {
                            Text("首页加载失败")
                        }
                    }
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        viewModel.load()
                    }
                    .buttonStyle(.borderedProminent)
                    if !isIPBlocked {
                        CloudflareVerifyButton(errorMessage: message)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height * 0.65)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        case .loaded(let snapshot):
            GeometryReader { container in
                ScrollView {
                    // Track the existing title crossfade in the scroll view's
                    // named coordinate space.
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: HomeScrollOffsetPreferenceKey.self,
                            value: -proxy.frame(in: .named("homeScroll")).minY
                        )
                    }
                    .frame(height: 0)

                    LazyVStack(alignment: .leading, spacing: 18) {
                        largeHomeTitle

                        if let banner = snapshot.banner {
                            HomeBannerView(
                                banner: banner,
                                videoFeature: videoFeature,
                                commentFeature: commentFeature,
                                usesCompactBanner: horizontalSizeClass == .regular
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, horizontalSizeClass == .regular ? 10 : 0)
                        }

                        ForEach(orderedSections(snapshot.sections)) { section in
                            HomeCategorySection(
                                section: section,
                                videoFeature: videoFeature,
                                commentFeature: commentFeature,
                                containerWidth: container.size.width
                            )
                        }
                    }
                    .padding(.vertical, 12)
                }
                .coordinateSpace(name: "homeScroll")
                .onPreferenceChange(HomeScrollOffsetPreferenceKey.self) { value in
                    // The fade finishes at 36pt. Further scrolling must not
                    // keep invalidating the whole home screen's state.
                    let titleOffset = min(36, max(0, value))
                    guard titleOffset != scrollOffset else { return }
                    scrollOffset = titleOffset
                }
                .overlay(alignment: .top) { inlineHomeTitle }
                .background(Color(.systemGroupedBackground))
                .sheet(isPresented: $showingCoverSettings) {
                    CompatibleNavigationStack {
                        VideoCoverSettingsView(
                            scope: .home,
                            containerWidth: container.size.width,
                            originalCoverWidth: VideoCoverSizing.defaultHomeWidth,
                            originalAspectRatio: VideoCoverLayout.landscape.aspectRatio
                        )
                    }
                    .presentationDetents([.medium, .large])
                }
            }
        }
    }

    private var coverSettingsButton: some View {
        Button { showingCoverSettings = true } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.body)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("调整封面", tableName: "VideoCover"))
    }

    private var largeHomeTitle: some View {
        Text("首页")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) { coverSettingsButton }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .opacity(1 - inlineTitleProgress)
            .allowsHitTesting(inlineTitleProgress < 0.5)
            .accessibilityHidden(inlineTitleProgress >= 0.5)
    }

    private var inlineHomeTitle: some View {
        Text("首页")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.bar)
            .overlay(alignment: .trailing) {
                coverSettingsButton.padding(.horizontal, 16)
            }
            .opacity(inlineTitleProgress)
            .allowsHitTesting(inlineTitleProgress >= 0.5)
            .accessibilityHidden(inlineTitleProgress < 0.5)
    }

    /// Reorders the snapshot's home sections according to the user's
    /// saved preference. Sections in the saved order are emitted first;
    /// any snapshot sections not yet ordered (e.g. new server sections)
    /// keep their original relative order at the end. Saved keys that
    /// no longer correspond to any current snapshot section are
    /// silently ignored.
    /// Apply the user's home-section preferences to the snapshot's
    /// sections. Two-step:
    /// 1. Drop any section listed in `home_section_hidden` (defaults to
    ///    `aiGenerated`).
    /// 2. Reorder the remaining sections by `home_section_order`. Sections
    ///    in the snapshot but absent from the saved order are appended at
    ///    the end (so newly added server sections still surface).
    /// Saved keys that don't correspond to any section in the snapshot
    /// are silently ignored.
    private func orderedSections(_ sections: [HomeSectionRow]) -> [HomeSectionRow] {
        let hidden = Set(homeSectionHiddenRaw.split(separator: ",").map(String.init))
        let filtered = sections.filter { !hidden.contains($0.key) }
        let preferred = homeSectionOrderRaw
            .split(separator: ",")
            .map(String.init)
        guard !preferred.isEmpty else { return filtered }
        let bySectionKey = Dictionary(uniqueKeysWithValues: filtered.map { ($0.key, $0) })
        var seen = Set<String>()
        var result: [HomeSectionRow] = []
        for key in preferred {
            if let section = bySectionKey[key], !seen.contains(key) {
                result.append(section)
                seen.insert(key)
            }
        }
        for section in filtered where !seen.contains(section.key) {
            result.append(section)
        }
        return result
    }
}

/// Reports HomeView's scroll offset so the self-drawn large title can
/// collapse into a compact inline header (option 3, see
/// docs/known-issues/nav-bar-title-crossfade-over-player.md).
private struct HomeScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct HomeBannerView: View {
    let banner: HomeBannerRow
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    let usesCompactBanner: Bool

    var body: some View {
        Group {
            if let videoCode = banner.videoCode, !videoCode.isEmpty {
                NavigationLink {
                    VideoDetailView(videoCode: videoCode, videoFeature: videoFeature, commentFeature: commentFeature)
                } label: {
                    bannerContent
                }
                .buttonStyle(.plain)
            } else {
                bannerContent
            }
        }
        .frame(maxWidth: .infinity, alignment: usesCompactBanner ? .leading : .center)
    }

    private var bannerContent: some View {
        bannerFrame
            // The website serves the home hero at a stable 16:9 ratio.
            // Fixing the container to the same ratio keeps its height
            // identical before and after the image finishes loading.
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(maxWidth: usesCompactBanner ? 440 : .infinity, alignment: usesCompactBanner ? .leading : .center)
            .frame(maxWidth: .infinity, alignment: usesCompactBanner ? .leading : .center)
    }

    private var bannerFrame: some View {
        ZStack(alignment: .bottomLeading) {
            CachedRemoteImage(urlString: banner.imageUrl, resizeWidth: 900)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(banner.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let description = banner.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct HomeCategorySection: View {
    let section: HomeSectionRow
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    let containerWidth: CGFloat
    @Environment(\.searchFeature) private var searchFeature
    @AppStorage(VideoCoverSizing.homeWidthKey) private var storedCoverWidth = VideoCoverSizing.automatic
    @AppStorage(VideoCoverSizing.homeAspectRatioKey) private var storedCoverRatio = VideoCoverSizing.automatic

    private var coverWidth: CGFloat {
        VideoCoverSizing.coverWidth(
            storedWidth: storedCoverWidth,
            originalWidth: VideoCoverSizing.defaultHomeWidth,
            containerWidth: containerWidth
        )
    }

    private var coverRatio: CGFloat {
        VideoCoverSizing.aspectRatio(
            storedRatio: storedCoverRatio,
            originalRatio: VideoCoverLayout.landscape.aspectRatio
        )
    }

    private var resizeWidth: CGFloat {
        guard VideoCoverSizing.isCustomized(storedCoverWidth)
                || VideoCoverSizing.isCustomized(storedCoverRatio) else { return 184 }
        return VideoCoverSizing.imageResizeWidth(
            coverWidth: coverWidth,
            ratio: coverRatio,
            originalRatio: VideoCoverLayout.landscape.aspectRatio
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text(section.title)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)

                Spacer()

                if let searchFeature {
                    NavigationLink {
                        ArtistVideosView(
                            title: section.title,
                            mode: .homeSection(SearchLaunchRequest(
                                sectionKey: section.key,
                                sectionTitle: section.title
                            )),
                            searchFeature: searchFeature,
                            videoFeature: videoFeature,
                            commentFeature: commentFeature
                        )
                    } label: {
                        Text("更多")
                            .font(.caption.weight(.semibold))
                    }
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(section.videos) { video in
                        NavigationLink {
                            VideoDetailView(videoCode: video.videoCode, videoFeature: videoFeature, commentFeature: commentFeature)
                        } label: {
                            HomeVideoCard(
                                video: video,
                                coverWidth: coverWidth,
                                coverRatio: coverRatio,
                                resizeWidth: resizeWidth
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct HomeVideoCard: View {
    let video: HomeVideoRow
    let coverWidth: CGFloat
    let coverRatio: CGFloat
    let resizeWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VideoCardCover(
                urlString: video.coverUrl,
                resizeWidth: resizeWidth,
                layout: .landscape,
                cornerRadius: 12,
                aspectRatio: coverRatio
            ) {
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, Color(.secondarySystemBackground).opacity(0.94)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 36)
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 5) {
                            if let views = video.views, !views.isEmpty {
                                Label(views, systemImage: "play.circle")
                            }
                            Spacer(minLength: 8)
                            if let duration = video.duration, !duration.isEmpty {
                                Label(duration, systemImage: "clock")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.bottom, 5)
                    }
                }
            }
            .frame(width: coverWidth)

            Text(video.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(height: 38, alignment: .topLeading)

            // Footer row: artist on the left (auto-scrolls if too long),
            // upload time on the right with fixed layout priority so it
            // always shows in full and the marquee gets the remainder.
            HStack(spacing: 6) {
                MarqueeText(text: video.artistLabel)
                if let uploadTime = video.uploadTime, !uploadTime.isEmpty {
                    Text(uploadTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }
            .frame(height: 17)
        }
        .frame(width: coverWidth, alignment: .leading)
        .videoCardSurface()
    }
}

private extension HomeVideoRow {
    var artistLabel: String {
        guard let artist, !artist.isEmpty else {
            return String(localized: "common.artist")
        }
        return artist
    }
}
