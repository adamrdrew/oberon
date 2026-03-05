import Testing
@testable import Oberon

struct DDGTokenServiceTests {

    @Test func mediaTypeRawValues() {
        #expect(DDGTokenService.MediaType.images.rawValue == "images")
        #expect(DDGTokenService.MediaType.videos.rawValue == "videos")
    }
}
