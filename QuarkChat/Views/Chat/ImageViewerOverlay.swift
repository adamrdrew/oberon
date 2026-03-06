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

    // Shared state
    @State private var selectedIndex: Int = 0
    @State private var scale: CGFloat = 1.0
    @State private var scaleAtGestureStart: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @State private var showChrome = true
    @State private var isPinching = false

    // iOS-only state
    #if os(iOS)
    private enum DragMode { case none, paging, dismissing, panning }
    @State private var dragMode: DragMode = .none
    @State private var pageDragOffset: CGFloat = 0
    @State private var dismissOffset: CGFloat = 0
    #endif

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isZoomed: Bool { scale > 1.05 }

    #if os(iOS)
    private var backgroundOpacity: Double {
        let progress = min(abs(dismissOffset) / 300.0, 1.0)
        return 1.0 - progress * 0.5
    }

    private var dismissScale: CGFloat {
        let progress = min(abs(dismissOffset) / 500.0, 1.0)
        return 1.0 - progress * 0.1
    }
    #endif

    var body: some View {
        ZStack {
            // Background
            #if os(iOS)
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
            #else
            Color.black
                .ignoresSafeArea()
            #endif

            // Image layer
            #if os(iOS)
            iOSImagePager
            #else
            macOSImageView
            #endif

            // Navigation arrows (macOS only)
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
        #if os(iOS)
        .statusBarHidden(!reduceMotion)
        #endif
        #if os(macOS)
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.3),
            value: selectedIndex
        )
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

    // MARK: - iOS Image Pager (custom HStack)

    #if os(iOS)
    private var iOSImagePager: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                    RemoteImageView(url: image.imageURL, contentMode: .fit)
                        .scaleEffect(index == selectedIndex ? scale : 1.0)
                        .offset(index == selectedIndex ? panOffset : .zero)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { handleDoubleTap() }
                        .onTapGesture { toggleChrome() }
                }
            }
            .offset(x: -CGFloat(selectedIndex) * geo.size.width + pageDragOffset)
            .offset(y: dismissOffset)
            .scaleEffect(dismissScale)
            .gesture(unifiedDragGesture(pageWidth: geo.size.width))
            .simultaneousGesture(pinchGesture)
        }
    }

    private func unifiedDragGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isPinching else { return }
                // Lock direction on first event (minimumDistance ensures enough movement)
                if dragMode == .none {
                    if isZoomed {
                        dragMode = .panning
                    } else if abs(value.translation.width) >= abs(value.translation.height) {
                        dragMode = .paging
                    } else {
                        dragMode = .dismissing
                    }
                }

                switch dragMode {
                case .paging:
                    var translation = value.translation.width
                    // Resistance at edges
                    if (selectedIndex == 0 && translation > 0) ||
                       (selectedIndex == images.count - 1 && translation < 0) {
                        translation *= 0.3
                    }
                    pageDragOffset = translation

                case .dismissing:
                    let vertical = value.translation.height
                    dismissOffset = vertical > 0 ? vertical : vertical * 0.3
                    if showChrome && abs(vertical) > 20 {
                        withAnimation(.easeOut(duration: 0.15)) { showChrome = false }
                    }

                case .panning:
                    panOffset = CGSize(
                        width: lastPanOffset.width + value.translation.width,
                        height: lastPanOffset.height + value.translation.height
                    )

                case .none:
                    break
                }
            }
            .onEnded { value in
                let mode = dragMode
                dragMode = .none

                switch mode {
                case .paging:
                    let threshold = pageWidth * 0.25
                    let velocity = value.predictedEndTranslation.width
                    if value.translation.width < -threshold || velocity < -500 {
                        // Next page
                        if selectedIndex < images.count - 1 {
                            resetZoom()
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                selectedIndex += 1
                                pageDragOffset = 0
                            }
                        } else {
                            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                pageDragOffset = 0
                            }
                        }
                    } else if value.translation.width > threshold || velocity > 500 {
                        // Previous page
                        if selectedIndex > 0 {
                            resetZoom()
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                selectedIndex -= 1
                                pageDragOffset = 0
                            }
                        } else {
                            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                pageDragOffset = 0
                            }
                        }
                    } else {
                        // Snap back
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                            pageDragOffset = 0
                        }
                    }

                case .dismissing:
                    let translation = value.translation.height
                    let predicted = value.predictedEndTranslation.height
                    if translation > 120 || predicted > 500 {
                        dismiss()
                    } else {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                            dismissOffset = 0
                        }
                        if !showChrome {
                            withAnimation(.spring(duration: 0.25, bounce: 0.1)) {
                                showChrome = true
                            }
                        }
                    }

                case .panning:
                    lastPanOffset = panOffset

                case .none:
                    break
                }
            }
    }
    #endif

    // MARK: - macOS Image View

    #if os(macOS)
    @ViewBuilder
    private var macOSImageView: some View {
        if let image = images[safe: selectedIndex] {
            RemoteImageView(url: image.imageURL, contentMode: .fit)
                .scaleEffect(scale)
                .offset(panOffset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { handleDoubleTap() }
                .onTapGesture { toggleChrome() }
                .gesture(pinchGesture)
                .gesture(panGesture)
                .id(image.id)
        }
    }

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

    // MARK: - Navigation

    private func navigatePrevious() {
        if selectedIndex > 0 {
            resetZoom()
            withAnimation(reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.15)) {
                selectedIndex -= 1
            }
        }
    }

    private func navigateNext() {
        if selectedIndex < images.count - 1 {
            resetZoom()
            withAnimation(reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.15)) {
                selectedIndex += 1
            }
        }
    }

    private func resetZoom() {
        scale = 1.0
        scaleAtGestureStart = 1.0
        panOffset = .zero
        lastPanOffset = .zero
    }

    // MARK: - Chrome

    private func toggleChrome() {
        withAnimation(.spring(duration: 0.25, bounce: 0.1)) {
            showChrome.toggle()
        }
    }

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

                if images.count > 1 {
                    Text("\(selectedIndex + 1) / \(images.count)")
                        .font(OTheme.label)
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.numericText())
                        .animation(
                            reduceMotion ? .none : .spring(duration: 0.3),
                            value: selectedIndex
                        )
                }
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
                isPinching = true
                scale = scaleAtGestureStart * value.magnification
            }
            .onEnded { _ in
                isPinching = false
                if scale < 1.0 {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        scale = 1.0
                        panOffset = .zero
                        lastPanOffset = .zero
                    }
                } else if scale > 4.0 {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        scale = 4.0
                    }
                }
                scaleAtGestureStart = min(max(scale, 1.0), 4.0)
            }
    }

    // macOS-only pan gesture (iOS uses unified drag)
    #if os(macOS)
    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard isZoomed else { return }
                panOffset = CGSize(
                    width: lastPanOffset.width + value.translation.width,
                    height: lastPanOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard isZoomed else { return }
                lastPanOffset = panOffset
            }
    }
    #endif

    private func handleDoubleTap() {
        if scale > 1.05 {
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                scale = 1.0
                panOffset = .zero
                lastPanOffset = .zero
            }
            scaleAtGestureStart = 1.0
        } else {
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                scale = 2.0
            }
            scaleAtGestureStart = 2.0
        }
    }
}

// MARK: - Safe Collection Subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
