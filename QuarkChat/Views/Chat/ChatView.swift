import SwiftUI
import SwiftData

struct ChatView: View {
    let conversation: Conversation

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = ChatViewModel()
    @State private var userProfile: UserProfile?
    @State private var scrollPosition = ScrollPosition(edge: .bottom)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                GlassEffectContainer(spacing: 20) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages, id: \.id) { message in
                            MessageBubble(
                                message: message,
                                userColor: Color(hex: viewModel.userBubbleColor) ?? .blue
                            )
                        }

                        if !viewModel.coordinator.pipelineSteps.isEmpty {
                            PipelineStatusView(steps: viewModel.coordinator.pipelineSteps)
                                .padding(.vertical, 8)
                                .transition(
                                    reduceMotion
                                        ? .opacity
                                        : .scale.combined(with: .opacity)
                                )
                        }

                        if viewModel.showTypingIndicator && viewModel.serviceStreamText.isEmpty {
                            TypingIndicator()
                                .transition(
                                    reduceMotion
                                        ? .opacity
                                        : .scale.combined(with: .opacity)
                                )
                        }

                        if !viewModel.serviceStreamText.isEmpty {
                            StreamingMessageView(text: viewModel.serviceStreamText)
                        }

                        if let error = viewModel.errorMessage {
                            ErrorMessageView(message: error)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .scrollPosition($scrollPosition)
            .defaultScrollAnchor(.bottom)
            .animation(.spring(duration: 0.3, bounce: 0.15), value: viewModel.coordinator.pipelineSteps.count)
            .animation(.spring(duration: 0.3, bounce: 0.15), value: viewModel.showTypingIndicator)
            .overlay {
                if viewModel.showGreeting {
                    greetingOverlay
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.4), value: viewModel.showGreeting)
                }
            }

            MessageInputBar(
                text: $viewModel.inputText,
                isGenerating: viewModel.isGenerating,
                onSend: {
                    Task { await viewModel.sendMessage() }
                },
                onStop: {
                    viewModel.stopGenerating()
                }
            )
        }
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

    @ViewBuilder
    private var greetingOverlay: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadUserProfile() {
        let descriptor = FetchDescriptor<UserProfile>()
        userProfile = try? modelContext.fetch(descriptor).first
    }
}
