import SwiftUI

/// The page behind this sheet observes the same AppStorage keys, so changes
/// preview immediately. Reset affects only the entry point that opened it.
struct VideoCoverSettingsView: View {
    let scope: VideoCoverScope
    let containerWidth: CGFloat
    let originalCoverWidth: CGFloat
    let originalAspectRatio: CGFloat

    @Environment(\.dismiss) private var dismiss
    @AppStorage private var storedWidth: Double
    @AppStorage private var storedRatio: Double

    init(
        scope: VideoCoverScope,
        containerWidth: CGFloat,
        originalCoverWidth: CGFloat,
        originalAspectRatio: CGFloat
    ) {
        self.scope = scope
        self.containerWidth = containerWidth
        self.originalCoverWidth = originalCoverWidth
        self.originalAspectRatio = originalAspectRatio
        _storedWidth = AppStorage(wrappedValue: VideoCoverSizing.automatic, scope.widthKey)
        _storedRatio = AppStorage(wrappedValue: VideoCoverSizing.automatic, scope.aspectRatioKey)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("封面大小")
                    Spacer()
                    Text(widthDescription)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                // Very narrow windows can leave only one possible width.
                // Keep its value visible without constructing a zero-span slider.
                if widthRange.lowerBound < widthRange.upperBound {
                    Slider(value: widthBinding, in: widthRange, step: 1) {
                        Text("封面大小")
                    } minimumValueLabel: {
                        Image(systemName: "minus.magnifyingglass")
                    } maximumValueLabel: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .accessibilityValue(widthDescription)
                }

                if !VideoCoverSizing.isCustomized(storedWidth),
                   originalCoverWidth < VideoCoverSizing.minimumCoverWidth {
                    Text("当前默认布局的封面较小，手动调节后从 96 pt 起。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("100% 为当前窗口下的原始大小。最小宽度 96 pt，上限随页面可用宽度调整；网格列数自动变化。")
            }

            Section {
                HStack {
                    Text("长宽比例")
                    Spacer()
                    Text(ratioDescription)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: ratioBinding, in: VideoCoverSizing.aspectRatioRange, step: 0.01) {
                    Text("长宽比例")
                } minimumValueLabel: {
                    Text(verbatim: "1:2")
                        .font(.caption)
                } maximumValueLabel: {
                    Text(verbatim: "3:1")
                        .font(.caption)
                }
                .accessibilityValue(ratioDescription)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ratioPreset("2:3", value: 2.0 / 3.0)
                        ratioPreset("1:1", value: 1)
                        ratioPreset("4:3", value: 4.0 / 3.0)
                        ratioPreset("16:9", value: 16.0 / 9.0)
                        ratioPreset("2:1", value: 2)
                    }
                }
            } footer: {
                Text("图片保持原比例，居中裁切以填满封面；调整比例后可能裁掉部分画面边缘。")
            }

            Section {
                Button("恢复默认") {
                    storedWidth = VideoCoverSizing.automatic
                    storedRatio = VideoCoverSizing.automatic
                }
            } footer: {
                Text("调整自动保存。首页横向列表与“更多”网格分别保存，恢复默认只影响当前这一处。")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
    }

    private var title: LocalizedStringKey {
        switch scope {
        case .home: "首页封面"
        case .homeSection: "更多页封面"
        }
    }

    private var widthRange: ClosedRange<Double> {
        VideoCoverSizing.widthRange(containerWidth: containerWidth)
    }

    private var effectiveWidth: CGFloat {
        VideoCoverSizing.coverWidth(
            storedWidth: storedWidth,
            originalWidth: originalCoverWidth,
            containerWidth: containerWidth
        )
    }

    private var effectiveRatio: CGFloat {
        VideoCoverSizing.aspectRatio(storedRatio: storedRatio, originalRatio: originalAspectRatio)
    }

    private var widthDescription: String {
        let percent = Int((effectiveWidth / max(1, originalCoverWidth) * 100).rounded())
        return "\(percent)% · \(Int(effectiveWidth.rounded())) pt"
    }

    private var ratioDescription: String {
        String(format: "%.2f:1", Double(effectiveRatio))
    }

    private var widthBinding: Binding<Double> {
        Binding(
            get: { min(widthRange.upperBound, max(widthRange.lowerBound, Double(effectiveWidth))) },
            set: { storedWidth = min(widthRange.upperBound, max(widthRange.lowerBound, $0)) }
        )
    }

    private var ratioBinding: Binding<Double> {
        Binding(
            get: { Double(effectiveRatio) },
            set: { storedRatio = $0 }
        )
    }

    private func ratioPreset(_ label: String, value: Double) -> some View {
        Button { storedRatio = value } label: {
            Text(verbatim: label)
                .font(.subheadline)
                .frame(minWidth: 44, minHeight: 30)
        }
        .buttonStyle(.bordered)
        .accessibilityAddTraits(abs(Double(effectiveRatio) - value) < 0.005 ? .isSelected : [])
    }
}
