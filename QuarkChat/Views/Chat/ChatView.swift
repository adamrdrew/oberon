import SwiftUI
import SwiftData

struct ChatView: View {
    let conversation: Conversation

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = ChatViewModel()
    @State private var userProfile: UserProfile?
    @State private var hasScrolledToBottom = false
    @State private var greetingAppeared = false

    private var isEmptyState: Bool {
        viewModel.messages.isEmpty && !viewModel.isGenerating
    }

    var body: some View {
        VStack(spacing: 0) {
            if isEmptyState {
                emptyStateView
            } else {
                activeChatView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isEmptyState)
        .navigationTitle(conversation.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            loadUserProfile()
            viewModel.configure(
                conversation: conversation,
                modelContext: modelContext,
                userProfile: userProfile
            )
        }
    }

    // MARK: - Empty State (centered greeting + input)

    @ViewBuilder
    private var emptyStateView: some View {
        Spacer()

        greetingContent

        Spacer()

        suggestedRepliesSection

        messageInputBar
    }

    // MARK: - Active Chat (scrollable messages + bottom input)

    @ViewBuilder
    private var activeChatView: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    GlassEffectContainer(spacing: 20) {
                        LazyVStack(spacing: 18) {
                            ForEach(viewModel.messages, id: \.id) { message in
                                MessageBubble(
                                    message: message,
                                    userColor: Color(hex: viewModel.userBubbleColor) ?? OTheme.navy,
                                    onActionExecute: { action in
                                        viewModel.executeAction(action)
                                    },
                                    onSpeakToggle: { msg in
                                        viewModel.toggleSpeech(for: msg)
                                    },
                                    onCopy: { msg in
                                        viewModel.copyMessage(msg)
                                    },
                                    isSpeaking: viewModel.ttsService.currentMessageID == message.id
                                )
                                .id(message.id)
                            }

                            // Pipeline + typing indicators
                            Group {
                                if !viewModel.livePipelineSteps.isEmpty {
                                    PipelineStatusView(steps: viewModel.livePipelineSteps)
                                        .padding(.vertical, 8)
                                        .transition(
                                            reduceMotion
                                                ? .opacity
                                                : .asymmetric(
                                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                                    removal: .opacity
                                                )
                                        )
                                }

                                if viewModel.showTypingIndicator && viewModel.serviceStreamText.isEmpty {
                                    TypingIndicator()
                                        .transition(
                                            reduceMotion
                                                ? .opacity
                                                : .asymmetric(
                                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                                    removal: .opacity
                                                )
                                        )
                                }
                            }
                            .animation(
                                reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.15),
                                value: viewModel.livePipelineSteps.count
                            )
                            .animation(
                                reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.15),
                                value: viewModel.showTypingIndicator
                            )

                            if !viewModel.serviceStreamText.isEmpty {
                                StreamingMessageView(text: viewModel.serviceStreamText)
                            }

                            if let error = viewModel.errorMessage {
                                ErrorMessageView(message: error)
                            }
                        }
                        .padding(.vertical, 12)
                    }

                    // Runway spacer: gives the ScrollView enough content below
                    // the last message so scrollTo(anchor: .top) can actually
                    // position it at the top of the viewport.
                    Color.clear
                        .frame(height: geo.size.height * 0.8)
                }
                .onAppear {
                    // Scroll to bottom when returning to an existing conversation
                    if !hasScrolledToBottom, viewModel.messages.count > 1,
                       let lastID = viewModel.messages.last?.id {
                        proxy.scrollTo(lastID, anchor: .bottom)
                        hasScrolledToBottom = true
                    }
                }
                .onChange(of: viewModel.scrollTargetMessageID, initial: true) { _, target in
                    guard let id = target else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.1))
                        }
                    }
                }
            }
        }

        suggestedRepliesSection

        messageInputBar
    }

    // MARK: - Shared Components

    @ViewBuilder
    private var greetingContent: some View {
        VStack(spacing: 8) {
            Text("OBERON")
                .font(OTheme.sectionHeader)
                .textCase(.uppercase)
                .tracking(3)
                .foregroundStyle(OTheme.tertiary)
                .opacity(greetingAppeared ? 1 : 0)

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48, design: .monospaced))
                .foregroundStyle(OTheme.accent)
                .padding(.bottom, 4)
                .scaleEffect(greetingAppeared ? 1 : 0.6)
                .opacity(greetingAppeared ? 1 : 0)

            StripeAccentView()
                .frame(width: 120)
                .opacity(greetingAppeared ? 1 : 0)

            if let headline = viewModel.greetingHeadline {
                Text(headline)
                    .font(OTheme.displayLarge)
                    .foregroundStyle(OTheme.primary)
                    .multilineTextAlignment(.center)
                    .scaleEffect(greetingAppeared ? 1 : 0.9)
                    .opacity(greetingAppeared ? 1 : 0)

                if let subtitle = viewModel.greetingSubtitle {
                    Text(subtitle)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundStyle(OTheme.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(greetingAppeared ? 1 : 0)
                }
            }
        }
        .animation(reduceMotion ? .none : .spring(duration: 0.5, bounce: 0.3), value: greetingAppeared)
        .onAppear {
            guard !reduceMotion else {
                greetingAppeared = true
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                greetingAppeared = true
            }
        }
    }

    @ViewBuilder
    private var suggestedRepliesSection: some View {
        Group {
            if !viewModel.isGenerating, let replies = viewModel.currentSuggestedReplies, !replies.isEmpty {
                SuggestedRepliesView(replies: replies) { text in
                    viewModel.inputText = text
                    Task { await viewModel.sendMessage() }
                }
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
                )
            }
        }
        .animation(
            reduceMotion ? .none : .spring(duration: 0.25, bounce: 0.1),
            value: viewModel.isGenerating
        )
    }

    private var messageInputBar: some View {
        MessageInputBar(
            text: $viewModel.inputText,
            isGenerating: viewModel.isGenerating,
            onSend: {
                Task { await viewModel.sendMessage() }
            },
            onStop: {
                viewModel.stopGenerating()
            },
            speechService: viewModel.speechService,
            onVoiceSend: { transcribed in
                viewModel.inputText = transcribed
                Task { await viewModel.sendMessage() }
            }
        )
    }

    // MARK: - Helpers

    private func loadUserProfile() {
        let descriptor = FetchDescriptor<UserProfile>()
        userProfile = try? modelContext.fetch(descriptor).first
    }
}
