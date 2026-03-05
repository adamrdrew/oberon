import SwiftUI

// MARK: - ViewableImage (universal wrapper)

struct ViewableImage: Identifiable {
    let id: String
    let imageURL: String
    let title: String?
    let sourceURL: String?

    init(from imageResult: ImageSearchData.ImageResult) {
        self.id = imageResult.id
        self.imageURL = imageResult.imageURL
        self.title = imageResult.title
        self.sourceURL = imageResult.sourceURL
    }

    init(from wikiImage: WikipediaData.WikipediaImage) {
        self.id = wikiImage.id
        self.imageURL = wikiImage.imageURL
        self.title = wikiImage.caption
        self.sourceURL = wikiImage.filePageURL
    }
}

// MARK: - Presentation Item

struct ImageViewerItem: Identifiable {
    let id = UUID()
    let images: [ViewableImage]
    let initialIndex: Int
}

// MARK: - ImageViewerOverlay

struct ImageViewerOverlay: View {
    let images: [ViewableImage]
    let initialIndex: Int

    @State private var selectedIndex: Int = 0
    @State private var scale: CGFloat = 1.0
    @State private var scaleAtGestureStart: CGFloat = 1.0
    @State private var showChrome = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Image display
            imagePageView(images[safe: selectedIndex])
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(duration: 0.25, bounce: 0.1)) {
                        showChrome.toggle()
                    }
                }

            // Navigation arrows (macOS)
            #if os(macOS)
            navigationArrows
            #endif

            // Chrome overlay
            if showChrome {
                chromeOverlay
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .move(edge: .top))
                    )
            }
        }
        .animation(
            reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.1),
            value: showChrome
        )
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.3),
            value: selectedIndex
        )
        #if os(iOS)
        .statusBarHidden(!reduceMotion)
        #endif
        #if os(macOS)
        .frame(minWidth: 700, idealWidth: 900, minHeight: 500, idealHeight: 700)
        #endif
        .onKeyPress(.leftArrow) {
            navigatePrevious()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            navigateNext()
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onAppear {
            selectedIndex = initialIndex
        }
    }

    // MARK: - Image Page

    @ViewBuilder
    private func imagePageView(_ image: ViewableImage?) -> some View {
        if let image {
            RemoteImageView(url: image.imageURL, contentMode: .fit)
                .scaleEffect(scale)
                .gesture(pinchGesture)
                .gesture(doubleTapGesture)
                .id(image.id)
        }
    }

    // MARK: - Navigation

    #if os(macOS)
    @ViewBuilder
    private var navigationArrows: some View {
        HStack {
            if selectedIndex > 0 {
                Button {
                    navigatePrevious()
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if selectedIndex < images.count - 1 {
                Button {
                    navigateNext()
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }
    #endif

    private func navigatePrevious() {
        if selectedIndex > 0 {
            scale = 1.0
            scaleAtGestureStart = 1.0
            withAnimation(reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.15)) {
                selectedIndex -= 1
            }
        }
    }

    private func navigateNext() {
        if selectedIndex < images.count - 1 {
            scale = 1.0
            scaleAtGestureStart = 1.0
            withAnimation(reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.15)) {
                selectedIndex += 1
            }
        }
    }

    // MARK: - Chrome

    @ViewBuilder
    private var chromeOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.8))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(selectedIndex + 1) / \(images.count)")
                    .font(OTheme.label)
                    .foregroundStyle(.white.opacity(0.7))
                    .contentTransition(.numericText())
                    .animation(
                        reduceMotion ? .none : .spring(duration: 0.3),
                        value: selectedIndex
                    )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            // Bottom caption
            if let title = images[safe: selectedIndex]?.title, !title.isEmpty {
                Text(title)
                    .font(OTheme.bodySmall)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Gestures

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = scaleAtGestureStart * value.magnification
            }
            .onEnded { _ in
                if scale < 1.0 {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        scale = 1.0
                    }
                } else if scale > 4.0 {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        scale = 4.0
                    }
                }
                scaleAtGestureStart = scale
            }
    }

    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                let target: CGFloat = scale > 1.0 ? 1.0 : 2.0
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    scale = target
                }
                scaleAtGestureStart = target
            }
    }
}

// MARK: - Safe Collection Subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
