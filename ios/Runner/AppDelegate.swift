import AVFoundation
import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var systemSpeech: SystemSpeechCapture?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "VocabKrNativeBridge") {
      systemSpeech = SystemSpeechCapture(messenger: registrar.messenger())
      FlutterMethodChannel(
        name: "vocab_kr/device_time_zone",
        binaryMessenger: registrar.messenger()
      ).setMethodCallHandler { call, result in
        if call.method == "get" {
          result(TimeZone.autoupdatingCurrent.identifier)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

private class SystemSpeechCapture {
  private class Session {
    let id: Int
    let recognizer: SFSpeechRecognizer
    let engine = AVAudioEngine()
    let request = SFSpeechAudioBufferRecognitionRequest()
    let previousCategory: AVAudioSession.Category
    let previousMode: AVAudioSession.Mode
    let previousOptions: AVAudioSession.CategoryOptions
    var task: SFSpeechRecognitionTask?
    var hasTap = false
    var changedAudioSession = false
    var releasing = false

    init(_ id: Int, recognizer: SFSpeechRecognizer, audio: AVAudioSession) {
      self.id = id
      self.recognizer = recognizer
      previousCategory = audio.category
      previousMode = audio.mode
      previousOptions = audio.categoryOptions
    }
  }

  private let channel: FlutterMethodChannel
  private var active: Session?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "vocab_kr/system_speech", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    if call.method == "supportsOnDeviceRecognition" {
      result(true) // Each requested locale is checked again before capture.
      return
    }
    guard let args = call.arguments as? [String: Any], let id = args["session"] as? Int else {
      result(FlutterError(code: "system_speech", message: "Missing session ID", details: nil))
      return
    }
    do {
      switch call.method {
      case "listen":
        guard let locale = args["locale"] as? String else {
          result(false)
          return
        }
        result(try start(id, locale: locale, onDevice: args["onDevice"] as? Bool ?? false))
      case "stop":
        guard let session = active, session.id == id else {
          result(false)
          return
        }
        try stop(session)
        result(true)
        channel.invokeMethod("released", arguments: ["session": id])
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(code: "system_speech", message: error.localizedDescription, details: nil))
    }
  }

  private func start(_ id: Int, locale: String, onDevice: Bool) throws -> Bool {
    guard active == nil,
      let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
      recognizer.isAvailable,
      !onDevice || recognizer.supportsOnDeviceRecognition
    else { return false }

    let audio = AVAudioSession.sharedInstance()
    let session = Session(id, recognizer: recognizer, audio: audio)
    active = session
    try audio.setCategory(.record, mode: .measurement)
    session.changedAudioSession = true
    try audio.setActive(true)
    session.request.requiresOnDeviceRecognition = onDevice
    session.request.shouldReportPartialResults = true
    let input = session.engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.channelCount > 0, format.sampleRate > 0 else {
      throw NSError(domain: "VocabKrSystemSpeechCapture", code: 1)
    }
    input.installTap(onBus: 0, bufferSize: 1024, format: format) {
      [request = session.request] buffer, _ in
      request.append(buffer)
    }
    session.hasTap = true
    session.engine.prepare()
    try session.engine.start()
    session.task = recognizer.recognitionTask(with: session.request) {
      [weak self, weak session] result, error in
      DispatchQueue.main.async {
        guard let self = self, let session = session,
          self.active === session, !session.releasing
        else { return }
        if let result = result {
          let alternatives = result.transcriptions.map { transcription -> [String: Any] in
            let segments = transcription.segments
            let confidence = segments.isEmpty
              ? -1.0
              : Double(segments.reduce(0) { $0 + $1.confidence }) / Double(segments.count)
            return ["words": transcription.formattedString, "confidence": confidence]
          }
          self.channel.invokeMethod("result", arguments: [
            "session": id, "alternates": alternatives, "isFinal": result.isFinal,
          ])
          if result.isFinal {
            self.channel.invokeMethod("status", arguments: ["session": id, "status": "done"])
          }
        } else if error != nil {
          self.channel.invokeMethod("error", arguments: [
            "session": id, "message": "error_recognition",
          ])
        }
      }
    }
    return true
  }

  private func stop(_ session: Session) throws {
    session.releasing = true
    session.engine.stop()
    if session.hasTap {
      session.engine.inputNode.removeTap(onBus: 0)
      session.hasTap = false
    }
    if let task = session.task {
      session.request.endAudio()
      task.cancel()
      session.task = nil
    }
    if session.changedAudioSession {
      let audio = AVAudioSession.sharedInstance()
      try audio.setActive(false, options: .notifyOthersOnDeactivation)
      try audio.setCategory(
        session.previousCategory, mode: session.previousMode, options: session.previousOptions)
    }
    active = nil
  }
}
