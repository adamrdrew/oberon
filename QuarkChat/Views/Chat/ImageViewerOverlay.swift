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

// MARK: - ImageViewerOverlay

struct ImageViewerOverlay: View {
    let images: [ViewableImage]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var showChrome = true
    @GestureState private var magnification: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Image pager
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                    imagePageView(image)
                        .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .onTapGesture {
                withAnimation(.spring(duration: 0.25, bounce: 0.1)) {
                    showChrome.toggle()
                }
            }

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
        #if os(iOS)
        .statusBarHidden(!reduceMotion)
        #endif
    }

    // MARK: - Image Page

    @ViewBuilder
    private func imagePageView(_ image: ViewableImage) -> some View {
        AsyncImage(url: URL(string: image.imageURL)) { phase in
            switch phase {
            case .success(let img):
                img
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale * magnification)
                    .gesture(pinchGesture)
                    .gesture(doubleTapGesture)
            case .failure:
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Failed to load")
                        .font(OTheme.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            case .empty:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            @unknown default:
                Color.clear
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
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.8))
                        .symbolRenderingMode(.hierarchical)
                }

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
            .updating($magnification) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                let newScale = scale * value.magnification
                if newScale < 1.0 {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        scale = 1.0
                    }
                } else {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        scale = min(newScale, 4.0)
                    }
                }
            }
    }

    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    scale = scale > 1.0 ? 1.0 : 2.0
                }
            }
    }
}

// MARK: - Safe Collection Subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
