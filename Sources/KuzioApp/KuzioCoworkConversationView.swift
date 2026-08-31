import IntatisCoworkUI
import IntatisSharedUI
import SwiftUI

/// Thin lifecycle host for the presentation-only Intatis Cowork right pane.
///
/// Kuzio contributes selected library context and runtime actions only. The
/// complete Cowork presentation is rendered by IntatisCoworkUI.
@MainActor
struct KuzioCoworkHarnessHost: View {
    let library: LibraryViewModel
    let target: KuzioCoworkConversationTarget

    @State private var model: KuzioCoworkHarnessHostModel
    @State private var showsInspector = false

    init(
        library: LibraryViewModel,
        target: KuzioCoworkConversationTarget
    ) {
        self.library = library
        self.target = target
        _model = State(initialValue: KuzioCoworkHarnessHostModel(
            target: target
        ))
    }

    var body: some View {
        @Bindable var harness = model

        IntatisCoworkContentView(
            state: contentState,
            threadSource: model.threadSource,
            actions: contentActions,
            input: $harness.input,
            showsInspector: $showsInspector
        )
        .accessibilityIdentifier("cowork.harness.intatis-cowork-ui")
        .task {
            await library.start()
            await model.start(using: library)
        }
        .onDisappear {
            Task {
                await model.shutdown()
            }
        }
    }

    private var contentState: IntatisCoworkContentState {
        IntatisCoworkContentState(
            sessionID: model.presentationSessionIdentity,
            sessionTitle: target.title,
            agents: model.agents,
            pendingPermission: model.pendingPermission,
            summary: model.summary,
            project: model.projectInfo,
            goal: model.goal,
            errorTexts: errorTexts,
            isWorking: model.isWorking,
            isAcceptingSubmission: model.isAcceptingSubmission,
            inferenceOptions: model.inferenceOptions,
            selectedInferenceBinding:
                model.selectedInferenceBinding
        )
    }

    private var contentActions: IntatisCoworkContentActions {
        IntatisCoworkContentActions(
            onSelectInference: {
                model.selectInferenceProfile($0)
            },
            onSend: {
                Task { await model.send() }
            },
            onCancelCurrent: cancelAction,
            onResolvePermission: { action in
                Task { await model.resolvePendingApproval(action) }
            },
            onPauseGoal: {
                Task { await model.pauseGoal() }
            },
            onResumeGoal: {
                Task { await model.resumeGoal() }
            },
            onClearGoal: {
                Task { await model.clearGoal() }
            }
        )
    }

    private var cancelAction: (() -> Void)? {
        guard model.isWorking else { return nil }
        return {
            Task { await model.interrupt() }
        }
    }

    private var errorTexts: [String] {
        model.errorMessage.map { [$0] } ?? []
    }
}
