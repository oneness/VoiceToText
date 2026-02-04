import Foundation

struct Transcription: Codable, Identifiable {
    let id: UUID
    var text: String
    let timestamp: Date

    init(text: String = "") {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
    }
}
