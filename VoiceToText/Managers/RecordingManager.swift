import Foundation
import AVFoundation
import Combine
import os.log

class RecordingManager: NSObject, ObservableObject {
    static let shared = RecordingManager()

    @Published var state: AppState = .idle

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private let logger = OSLog(subsystem: "com.voicetext.app", category: "RecordingManager")

    // Callback for when recording stops with an audio file
    var onRecordingComplete: ((URL) -> Void)?

    private override init() {
        super.init()
        setupAudioSession()
        os_log("RecordingManager initialized", log: logger, type: .info)
    }

    private func setupAudioSession() {
        // AVAudioSession is iOS-only - not needed on macOS
        os_log("Audio recording ready on macOS", log: logger, type: .info)
    }

    func startRecording() {
        os_log("Starting audio recording...", log: logger, type: .info)

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

            os_log("Recording started to: %@", log: logger, type: .info, fileURL.path)
        } catch {
            os_log("Failed to start recording: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }

    func stopRecording() {
        os_log("Stopping audio recording...", log: logger, type: .info)

        audioRecorder?.stop()

        // Don't set state to .idle here - let the callback handler do it
        // Wait a moment for the recorder to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let url = self?.recordingURL {
                os_log("Recording saved to: %@", log: self?.logger ?? OSLog.default, type: .info, url.path)
                os_log("Calling onRecordingComplete callback", log: self?.logger ?? OSLog.default, type: .info)
                // State will be set to .transcribing by callback, then .idle when done
                self?.onRecordingComplete?(url)
                os_log("onRecordingComplete callback called", log: self?.logger ?? OSLog.default, type: .info)
            }
        }
    }

    func toggle() {
        os_log("toggle() called, state: %@", log: logger, type: .info, state.displayName)
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .transcribing:
            // If transcribing, don't allow toggle
            os_log("Cannot toggle while transcribing", log: logger, type: .info)
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
        os_log("Recording finished, success: %@", log: logger, type: .info, flag ? "YES" : "NO")
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            os_log("Recording error: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
}
