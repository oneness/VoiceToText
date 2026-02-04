import Foundation
import AVFoundation
import Combine

class RecordingManager: NSObject, ObservableObject {
    static let shared = RecordingManager()

    @Published var state: AppState = .idle

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    // Callback for when recording stops with an audio file
    var onRecordingComplete: ((URL) -> Void)?

    private override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
            print("DEBUG: Audio session configured for recording")
        } catch {
            print("ERROR: Failed to setup audio session: \(error)")
        }
    }

    func startRecording() {
        print("DEBUG: Starting audio recording...")
        NSLog("Starting audio recording...")

        // Create temporary file path
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "recording_\(Int(Date().timeIntervalSince1970)).m4a"
        let fileURL = tempDir.appendingPathComponent(filename)

        // Define recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44100.0,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            recordingURL = fileURL
            state = .recording

            print("DEBUG: Recording started to: \(fileURL.path)")
            NSLog("Recording started to: %@", fileURL.path)
        } catch {
            print("ERROR: Failed to start recording: \(error)")
            NSLog("ERROR: Failed to start recording: %@", error.localizedDescription)
        }
    }

    func stopRecording() {
        print("DEBUG: Stopping audio recording...")
        NSLog("Stopping audio recording...")

        audioRecorder?.stop()

        // Wait a moment for the recorder to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let url = self?.recordingURL {
                print("DEBUG: Recording saved to: \(url.path)")
                NSLog("Recording saved to: %@", url.path)
                self?.state = .idle
                self?.onRecordingComplete?(url)
            }
        }
    }

    func toggle() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .transcribing:
            // If transcribing, don't allow toggle
            print("Cannot toggle while transcribing")
        }
    }

    // Set the recording URL (to be called when actual recording is implemented)
    func setRecordingURL(_ url: URL) {
        self.recordingURL = url
    }
}

// MARK: - AVAudioRecorderDelegate

extension RecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("DEBUG: Recording finished, success: \(successfully flag)")
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("ERROR: Recording error: \(error.localizedDescription)")
            NSLog("ERROR: Recording error: %@", error.localizedDescription)
        }
    }
}
