// Stand-ins for the parts of AVFoundation the app uses (see UIKit.swift).
@_exported import Foundation

public typealias AVAudioFrameCount = UInt32
public typealias AVAudioChannelCount = UInt32
public typealias AVAudioNodeCompletionHandler = () -> Void

open class AVAudioTime: NSObject {}

open class AVAudioFormat: NSObject {
    public init?(standardFormatWithSampleRate sampleRate: Double, channels: AVAudioChannelCount) {}
}

open class AVAudioPCMBuffer: NSObject {
    public init?(pcmFormat format: AVAudioFormat, frameCapacity: AVAudioFrameCount) {}
    open var frameLength: AVAudioFrameCount = 0
    open var floatChannelData: UnsafePointer<UnsafeMutablePointer<Float>>? { nil }
}

open class AVAudioNode: NSObject {}
open class AVAudioMixerNode: AVAudioNode {}
open class AVAudioUnit: AVAudioNode {}
open class AVAudioUnitTimeEffect: AVAudioUnit {}

open class AVAudioUnitVarispeed: AVAudioUnitTimeEffect {
    open var rate: Float = 1
    public override init() {}
}

public struct AVAudioPlayerNodeBufferOptions: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let loops = AVAudioPlayerNodeBufferOptions(rawValue: 1)
    public static let interrupts = AVAudioPlayerNodeBufferOptions(rawValue: 2)
    public static let interruptsAtLoop = AVAudioPlayerNodeBufferOptions(rawValue: 4)
}

open class AVAudioPlayerNode: AVAudioNode {
    open var volume: Float = 1
    open var isPlaying: Bool { false }
    public override init() {}
    open func play() {}
    open func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime?,
                             options: AVAudioPlayerNodeBufferOptions = [],
                             completionHandler: AVAudioNodeCompletionHandler? = nil) {}
}

open class AVAudioEngine: NSObject {
    open var mainMixerNode: AVAudioMixerNode { AVAudioMixerNode() }
    public override init() {}
    open func attach(_ node: AVAudioNode) {}
    open func connect(_ node1: AVAudioNode, to node2: AVAudioNode, format: AVAudioFormat?) {}
    open func start() throws {}
}

open class AVAudioSession: NSObject {
    public struct Category: Hashable { public static let ambient = Category() }
    open class func sharedInstance() -> AVAudioSession { AVAudioSession() }
    open func setCategory(_ category: Category) throws {}
}
