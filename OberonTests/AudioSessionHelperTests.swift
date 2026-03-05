import Testing
@testable import Oberon

struct AudioSessionHelperTests {

    @Test func activateDoesNotThrow() {
        // On macOS this is a no-op. Verify it doesn't crash.
        AudioSessionHelper.activatePlaybackSession()
    }

    @Test func deactivateDoesNotThrow() {
        AudioSessionHelper.deactivateSession()
    }
}
