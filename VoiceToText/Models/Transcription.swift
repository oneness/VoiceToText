import Foundation

struct Transcription: Codable, Identifiable {
    let id: UUID
    var text: String
    let timestamp: Date
}
