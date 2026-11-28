import AVFoundation
import Flutter

/// Owns the synth and completes speech and stop only for the tracked utterance.
final class DeviceSpeech: NSObject, AVSpeechSynthesizerDelegate {
  private final class StopAttempt {
    let reply: FlutterResult

    init(_ reply: @escaping FlutterResult) {
      self.reply = reply
    }
  }

  private final class Speech {
    let client: Int
    let utterance: AVSpeechUtterance
    let reply: FlutterResult
    var stop: StopAttempt?

    init(client: Int, utterance: AVSpeechUtterance, reply: @escaping FlutterResult) {
      self.client = client
      self.utterance = utterance
      self.reply = reply
    }
  }

  private let channel: FlutterMethodChannel
  private let synthesizer = AVSpeechSynthesizer()
  private var active: Speech?
  private var configuredVoice: (locale: String, voice: AVSpeechSynthesisVoice)?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "vocab_kr/device_speech", binaryMessenger: messenger)
    super.init()
    synthesizer.delegate = self
    channel.setMethodCallHandler { [weak self] call, reply in
      guard let self = self else {
        reply(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, reply: reply)
    }
  }

  private func handle(_ call: FlutterMethodCall, reply: @escaping FlutterResult) {
    switch call.method {
    case "warmUp", "speak":
      guard active == nil,
        let args = call.arguments as? [String: Any],
        let client = args["client"] as? Int,
        let locale = args["locale"] as? String,
        let rate = args["rate"] as? Double,
        let pitch = args["pitch"] as? Double,
        let voice = voice(for: locale)
      else {
        reply(0)
        return
      }
      if call.method == "warmUp" {
        reply(1)
        return
      }
      guard let text = args["text"] as? String else {
        reply(0)
        return
      }
      let utterance = AVSpeechUtterance(string: text)
      utterance.voice = voice
      utterance.rate = Float(rate)
      utterance.pitchMultiplier = Float(pitch)
      active = Speech(client: client, utterance: utterance, reply: reply)
      synthesizer.speak(utterance)
    case "stop":
      guard let client = call.arguments as? Int else {
        reply(0)
        return
      }
      stop(client: client, reply: reply)
    default:
      reply(FlutterMethodNotImplemented)
    }
  }

  private func voice(for locale: String) -> AVSpeechSynthesisVoice? {
    if let cached = configuredVoice, cached.locale == locale { return cached.voice }
    guard let voice = AVSpeechSynthesisVoice(language: locale) else { return nil }
    configuredVoice = (locale, voice)
    return voice
  }

  private func stop(client: Int, reply: @escaping FlutterResult) {
    guard let speech = active else {
      reply(1)
      return
    }
    guard speech.client == client, speech.stop == nil,
      synthesizer.stopSpeaking(at: .immediate)
    else {
      reply(0)
      return
    }
    let attempt = StopAttempt(reply)
    speech.stop = attempt
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(750)) { [weak self] in
      guard self?.active === speech, speech.stop === attempt else { return }
      speech.stop = nil
      attempt.reply(0)
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    terminal(utterance, completed: true)
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    terminal(utterance, completed: false)
  }

  private func terminal(_ utterance: AVSpeechUtterance, completed: Bool) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let speech = self.active, speech.utterance === utterance else { return }
      self.active = nil
      speech.reply(completed && speech.stop == nil ? 1 : 0)
      speech.stop?.reply(1)
    }
  }
}
