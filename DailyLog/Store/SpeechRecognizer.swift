import Foundation
import AVFoundation
import Speech
import SwiftUI

/// 语音转文字。
/// 优先使用设备端离线识别（`requiresOnDeviceRecognition`），识别结果实时追加到正文。
@MainActor
final class SpeechRecognizer: ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var errorText: String?
    /// 0~1 的实时音量，用来画波形
    @Published private(set) var level: CGFloat = 0

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var baseText = ""
    private var onUpdate: ((String) -> Void)?

    /// 设备端离线识别是否可用（不可用时回退到系统在线识别）
    var isOnDevice: Bool {
        SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))?.supportsOnDeviceRecognition ?? false
    }

    // MARK: - 开关

    func toggle(baseText: String, onUpdate: @escaping (String) -> Void) async {
        if isRecording {
            stop()
        } else {
            await start(baseText: baseText, onUpdate: onUpdate)
        }
    }

    func start(baseText: String, onUpdate: @escaping (String) -> Void) async {
        guard !isRecording else { return }
        errorText = nil
        self.baseText = baseText
        self.onUpdate = onUpdate

        guard await requestPermissions() else { return }

        let locale = Locale(identifier: "zh-CN")
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            errorText = "这台设备暂时无法识别中文语音"
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorText = "无法启动麦克风：\(error.localizedDescription)"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // 能离线就离线，识别内容不出设备
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            errorText = "没有检测到可用的麦克风"
            teardown()
            return
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let value = meterLevel(buffer)
            Task { @MainActor in
                self?.level = value
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            errorText = "无法启动麦克风：\(error.localizedDescription)"
            teardown()
            return
        }

        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let said = result.bestTranscription.formattedString
                    let joined = self.baseText.isEmpty ? said : self.baseText + "\n" + said
                    self.onUpdate?(joined)
                    if result.isFinal { self.stop() }
                }
                if error != nil { self.stop() }
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        teardown()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - 权限

    private func requestPermissions() async -> Bool {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            errorText = "还没允许语音识别，请到「设置 → 每日记录」里打开「语音识别」"
            return false
        }

        let micGranted: Bool = await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        guard micGranted else {
            errorText = "还没允许麦克风，请到「设置 → 每日记录」里打开「麦克风」"
            return false
        }
        return true
    }

    // MARK: - 内部

    /// 停掉引擎、拆掉音频回调
    private func teardown() {
        if engine.isRunning {
            engine.stop()
        }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        level = 0
    }
}

/// 在音频线程调用，所以放在类型外面，避免 actor 隔离问题
private func meterLevel(_ buffer: AVAudioPCMBuffer) -> CGFloat {
    guard let channel = buffer.floatChannelData?[0] else { return 0 }
    let count = Int(buffer.frameLength)
    guard count > 0 else { return 0 }

    var sum: Float = 0
    for i in 0..<count {
        sum += channel[i] * channel[i]
    }
    let rms = sqrt(sum / Float(count))
    let db = 20 * log10(max(rms, 0.000_000_1))
    return CGFloat(max(0, min(1, (db + 55) / 55)))
}
