import SwiftUI
import UIKit
import Han1meShared

struct FollowingView: View {
    @StateObject private var viewModel: FollowingViewModel
    @State private var isArtistsExpanded = false
    /// Keep destinations outside the lazy containers; cells only select an item.
    @State private var pushedArtist: FollowingArtistRow?
    @State private var pushedVideoCode: String?
    @AppStorage("following_updates_layout") private var updatesLayout = "list"
    @AppStorage("following_updates_grid_columns") private var gridColumnCount = 3
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature
    private let searchFeature: SearchFeature

    init(environment: SharedAppEnvironment) {
        self.videoFeature = environment.videoFeature()
        self.commentFeature = environment.commentFeature()
        self.searchFeature = environment.searchFeature()
        _viewModel = StateObject(wrappedValue: FollowingViewModel(followingFeature: environment.followingFeature()))
    }

    var body: some View {
        CompatibleNavigationStack {
            GeometryReader { container in
                content(containerWidth: container.size.width)
                    .navigationTitle("关注")
                    .logScreen("Following")
                    .refreshable {
                        await viewModel.refresh()
                    }
            }
        }
        .task {
            viewModel.loadIfNeeded()
        }
        .onDisappear {
            viewModel.cancelLoading()
        }
    }

    @ViewBuilder
    private func content(containerWidth: CGFloat) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "heart.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("关注加载失败")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试") {
                    viewModel.load()
                }
                .buttonStyle(.borderedProminent)
                CloudflareVerifyButton(errorMessage: message)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let snapshot), .loadingMore(let snapshot):
            Group {
                if isGridLayout {
                    gridContent(snapshot: snapshot, containerWidth: containerWidth)
                } else {
                    listContent(snapshot: snapshot)
                }
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { pushedArtist != nil },
                    set: { if !$0 { pushedArtist = nil } }
                )
            ) {
                if let pushedArtist {
                    ArtistVideosView(
                        title: pushedArtist.name,
                        mode: .subscribedArtist(pushedArtist.name),
                        searchFeature: searchFeature,
                        videoFeature: videoFeature,
                        commentFeature: commentFeature
                    )
                }
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { pushedVideoCode != nil },
                    set: { if !$0 { pushedVideoCode = nil } }
                )
            ) {
                if let pushedVideoCode {
                    VideoDetailView(
                        videoCode: pushedVideoCode,
                        videoFeature: videoFeature,
                        commentFeature: commentFeature
                    )
                }
            }
        }
    }

    // List must own individual list rows, never one row containing the whole
    // video grid. A self-sizing List cell measures that grid's complete height,
    // creating offscreen cards/images and firing pagination before scrolling.
    private func listContent(snapshot: FollowingScreenSnapshot) -> some View {
        List {
            if !snapshot.artists.isEmpty {
                Section {
                    artistsContent(snapshot: snapshot)
                } header: {
                    artistsHeader
                }
            }
            Section {
                if snapshot.videos.isEmpty {
                    emptyUpdates
                } else {
                    ForEach(snapshot.videos) { video in
                        NavigationLink {
                            VideoDetailView(
                                videoCode: video.videoCode,
                                videoFeature: videoFeature,
                                commentFeature: commentFeature
                            )
                        } label: {
                            FollowingVideoRowView(video: video)
                        }
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentItemID: video.id)
                        }
                    }
                    followingFooter(snapshot: snapshot)
                }
            } header: {
                updatesHeader
            }
        }
        .listStyle(.insetGrouped)
    }

    private func gridContent(snapshot: FollowingScreenSnapshot, containerWidth: CGFloat) -> some View {
        let resizeWidth = followingGridImageResizeWidth(containerWidth: containerWidth)
        return ScrollView {
            // The ScrollView viewport, not an unbounded List cell, now drives
            // lazy card creation. Keep the automatic pagination footer lazy too.
            LazyVStack(spacing: 12) {
                if !snapshot.artists.isEmpty {
                    artistsHeader
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    artistsContent(snapshot: snapshot)
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                updatesHeader
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Stepper(value: $gridColumnCount, in: 1...VideoCoverSizing.maximumGridColumnCount) {
                    HStack {
                        Text("列数", tableName: "FollowingLayout")
                        Spacer()
                        Text("\(effectiveGridColumnCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if snapshot.videos.isEmpty {
                    emptyUpdates
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVGrid(columns: followingGridColumns, spacing: 12) {
                        ForEach(snapshot.videos) { video in
                            Button {
                                pushedVideoCode = video.videoCode
                            } label: {
                                FollowingVideoGridCard(video: video, resizeWidth: resizeWidth)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: video.title))
                            .onAppear {
                                if video.id == snapshot.videos.last?.id {
                                    viewModel.loadMoreIfNeeded(currentItemID: video.id)
                                }
                            }
                        }
                    }
                    followingFooter(snapshot: snapshot)
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    @ViewBuilder
    private func artistsContent(snapshot: FollowingScreenSnapshot) -> some View {
        if isArtistsExpanded {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 14)], spacing: 14) {
                ForEach(snapshot.artists) { artist in
                    artistButton(artist)
                }
            }
            .padding(.vertical, 4)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(snapshot.artists) { artist in
                        artistButton(artist)
                    }
                }
                .padding(.vertical, 4)
            }
            // A lazy horizontal stack needs an explicit cross-axis extent.
            .frame(height: 88)
        }
    }

    private func artistButton(_ artist: FollowingArtistRow) -> some View {
        Button {
            pushedArtist = artist
        } label: {
            FollowingArtistCell(artist: artist)
        }
        .buttonStyle(.plain)
    }

    private var artistsHeader: some View {
        HStack {
            Text("订阅作者")
            Spacer()
            Button {
                // Do not animate reflow of a potentially large video grid.
                isArtistsExpanded.toggle()
            } label: {
                HStack(spacing: 2) {
                    Text(isArtistsExpanded ? "收起" : "展开")
                    Image(systemName: isArtistsExpanded ? "chevron.up" : "chevron.down")
                        .imageScale(.small)
                }
                .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
        .textCase(nil)
    }

    private var updatesHeader: some View {
        HStack {
            Text("关注更新")
            Spacer()
            Menu {
                Picker(selection: $updatesLayout) {
                    Text("列表", tableName: "FollowingLayout").tag("list")
                    Text("网格", tableName: "FollowingLayout").tag("grid")
                } label: {
                    Text("显示方式", tableName: "FollowingLayout")
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: isGridLayout ? "square.grid.2x2" : "list.bullet")
                    .frame(width: 36, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("更新布局", tableName: "FollowingLayout"))
        }
        .textCase(nil)
    }

    private var emptyUpdates: some View {
        Text("暂无关注更新。")
            .foregroundStyle(.secondary)
    }

    private var isGridLayout: Bool {
        updatesLayout == "grid"
    }

    private var effectiveGridColumnCount: Int {
        min(VideoCoverSizing.maximumGridColumnCount, max(1, gridColumnCount))
    }

    private var followingGridColumns: [GridItem] {
        VideoCoverSizing.flexibleGridColumns(
            columnCount: effectiveGridColumnCount,
            spacing: 12
        )
    }

    private func followingGridImageResizeWidth(containerWidth: CGFloat) -> CGFloat {
        let availableWidth = max(1, containerWidth - VideoCoverSizing.pageHorizontalPadding)
        let count = effectiveGridColumnCount
        let columnWidth = (availableWidth - CGFloat(count - 1) * 12) / CGFloat(count)
        return VideoCoverSizing.imageResizeWidth(
            coverWidth: max(1, columnWidth - VideoCoverSizing.cardHorizontalPadding),
            ratio: VideoCoverLayout.landscape.aspectRatio,
            originalRatio: VideoCoverLayout.landscape.aspectRatio
        )
    }

    @ViewBuilder
    private func followingFooter(snapshot: FollowingScreenSnapshot) -> some View {
        PaginationFooterView(
            isLoadingMore: {
                if case .loadingMore = viewModel.state { return true }
                return false
            }(),
            hasNext: snapshot.hasNext,
            loadMoreError: snapshot.loadMoreError,
            isEmpty: snapshot.videos.isEmpty,
            onRetry: {
                viewModel.loadMoreIfNeeded(currentItemID: snapshot.videos.last?.id)
            }
        )
    }
}

private struct FollowingArtistCell: View {
    let artist: FollowingArtistRow

    var body: some View {
        VStack(spacing: 8) {
            CachedRemoteImage(urlString: artist.avatarUrl, resizeWidth: 58)
                .frame(width: 58, height: 58)
                .clipShape(Circle())
            Text(artist.name)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 72)
        }
    }
}

private struct FollowingVideoRowView: View {
    let video: FollowingVideoRow

    var body: some View {
        HStack(spacing: 12) {
            CachedRemoteImage(urlString: video.coverUrl, resizeWidth: 96)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .lineLimit(2)
                if !video.metadata.isEmpty {
                    Text(video.metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FollowingVideoGridCard: View {
    let video: FollowingVideoRow
    let resizeWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VideoCardCover(
                urlString: video.coverUrl,
                resizeWidth: resizeWidth,
                layout: .landscape
            ) {
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.68)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 34)
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 5) {
                            if let views = video.views, !views.isEmpty {
                                Label(views, systemImage: "play.circle")
                            }
                            Spacer(minLength: 4)
                            if let duration = video.duration, !duration.isEmpty {
                                Label(duration, systemImage: "clock")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.bottom, 5)
                    }
                }
            }

            Text(video.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 38, alignment: .topLeading)

            HStack(spacing: 6) {
                if let artist = video.artist, !artist.isEmpty {
                    Text(artist)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer(minLength: 0)
                }
                if let uploadTime = video.uploadTime, !uploadTime.isEmpty {
                    Text(uploadTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(height: 17)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .videoCardSurface()
    }
}
