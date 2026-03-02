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
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            MessageBubble(
                                message: message,
                                userColor: Color(hex: viewModel.userBubbleColor) ?? .blue
                            )
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .push(from: .bottom).combined(with: .opacity)
                            )
                        }

                        if let toolName = viewModel.serviceActiveToolName {
                            ToolUseIndicator(toolName: toolName)
                                .transition(
                                    reduceMotion
                                        ? .opacity
                                        : .scale.combined(with: .opacity)
                                )
                        } else if viewModel.showTypingIndicator && viewModel.serviceStreamText.isEmpty {
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
            .animation(.spring(duration: 0.35, bounce: 0.2), value: viewModel.messages.count)
            .animation(.spring(duration: 0.3, bounce: 0.15), value: viewModel.isGenerating)
            .animation(.spring(duration: 0.3, bounce: 0.15), value: viewModel.serviceActiveToolName)
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
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            if let greeting = viewModel.greetingText {
                Text(greeting)
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
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
