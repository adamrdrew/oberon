import SwiftUI
import SwiftData

struct ChatView: View {
    let conversation: Conversation

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = ChatViewModel()
    @State private var userProfile: UserProfile?
    @State private var hasScrolledToBottom = false

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
                                    userColor: Color(hex: viewModel.userBubbleColor) ?? .blue,
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
                                if !viewModel.coordinator.pipelineSteps.isEmpty {
                                    PipelineStatusView(steps: viewModel.coordinator.pipelineSteps)
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
                                value: viewModel.coordinator.pipelineSteps.count
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
                            proxy.scrollTo(id, anchor: .top)
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
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)

            if let headline = viewModel.greetingHeadline {
                Text(headline)
                    .font(.title)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                if let subtitle = viewModel.greetingSubtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                ProgressView()
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
