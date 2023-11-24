import Foundation
import VideoToolbox

/// The VideoCodecSettings class  specifying video compression settings.
public struct VideoCodecSettings: Codable {
    /// The defulat value.
    public static let `default` = VideoCodecSettings()

    /// A bitRate mode that affectes how to encode the video source.
    public enum BitRateMode: String, Codable {
        /// The average bit rate.
        case average
        /// The constant bit rate.
        @available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
        case constant

        var key: VTSessionOptionKey {
            if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
                switch self {
                case .average:
                    return .averageBitRate
                case .constant:
                    return .constantBitRate
                }
            }
            return .averageBitRate
        }
    }

    /**
     * The scaling mode.
     * - seealso: https://developer.apple.com/documentation/videotoolbox/kvtpixeltransferpropertykey_scalingmode
     * - seealso: https://developer.apple.com/documentation/videotoolbox/vtpixeltransfersession/pixel_transfer_properties/scaling_mode_constants
     */
    public enum ScalingMode: String, Codable {
        /// kVTScalingMode_Normal
        case normal = "Normal"
        /// kVTScalingMode_Letterbox
        case letterbox = "Letterbox"
        /// kVTScalingMode_CropSourceToCleanAperture
        case cropSourceToCleanAperture = "CropSourceToCleanAperture"
        /// kVTScalingMode_Trim
        case trim = "Trim"
    }

    /// The type of the VideoCodec supports format.
    enum Format: Codable {
        case h264
        case hevc

        #if os(macOS)
        var encoderID: NSString {
            switch self {
            case .h264:
                #if arch(arm64)
                return NSString(string: "com.apple.videotoolbox.videoencoder.ave.avc")
                #else
                return NSString(string: "com.apple.videotoolbox.videoencoder.h264.gva")
                #endif
            case .hevc:
                return NSString(string: "com.apple.videotoolbox.videoencoder.ave.hevc")
            }
        }
        #endif

        var codecType: UInt32 {
            switch self {
            case .h264:
                return kCMVideoCodecType_H264
            case .hevc:
                return kCMVideoCodecType_HEVC
            }
        }
    }

    /// Specifies the video size of encoding video.
    public var videoSize: VideoSize
    /// Specifies the bitrate.
    public var bitRate: UInt32
    /// Specifies the keyframeInterval.
    public var maxKeyFrameIntervalDuration: Int32
    /// Specifies the scalingMode.
    public var scalingMode: ScalingMode
    /// Specifies the allowFrameRecording.
    public var allowFrameReordering: Bool? // swiftlint:disable:this discouraged_optional_boolean
    /// Specifies the bitRateMode.
    public var bitRateMode: BitRateMode
    /// Specifies the H264 profileLevel.
    public var profileLevel: String {
        didSet {
            if profileLevel.contains("HEVC") {
                format = .hevc
            } else {
                format = .h264
            }
        }
    }
    /// Specifies the HardwareEncoder is enabled(TRUE), or not(FALSE) for macOS.
    public var isHardwareEncoderEnabled = true

    var format: Format = .h264

    var realtime: Bool = false
    var allowTemporalCompression: Bool? = nil
    var dataLimiteLate: Float?
    var maxDelayFrameCount: Int?
    var maxQP: Int?
    var minQP: Int?
    
    /// Creates a new VideoCodecSettings instance.
    public init(
        videoSize: VideoSize = .init(width: 854, height: 480),
        profileLevel: String = kVTProfileLevel_H264_Baseline_3_1 as String,
        bitRate: UInt32 = 640 * 1000,
        maxKeyFrameIntervalDuration: Int32 = 2,
        scalingMode: ScalingMode = .trim,
        bitRateMode: BitRateMode = .average,
        allowFrameReordering: Bool? = nil, // swiftlint:disable:this discouraged_optional_boolean
        allowTemporalCompression: Bool? = nil, // swiftlint:disable:this discouraged_optional_boolean
        isHardwareEncoderEnabled: Bool = true,
        realtime: Bool = false,
        dataLimiteLate: Float? = nil,
        maxDelayFrameCount: Int? = nil,
        maxQP: Int? = nil,
        minQP: Int? = nil
    ) {
        self.videoSize = videoSize
        self.profileLevel = profileLevel
        self.bitRate = bitRate
        self.maxKeyFrameIntervalDuration = maxKeyFrameIntervalDuration
        self.scalingMode = scalingMode
        self.bitRateMode = bitRateMode
        self.allowFrameReordering = allowFrameReordering
        self.isHardwareEncoderEnabled = isHardwareEncoderEnabled
        if profileLevel.contains("HEVC") {
            self.format = .hevc
        }
        self.realtime = realtime
        self.allowTemporalCompression = allowTemporalCompression
        self.dataLimiteLate = dataLimiteLate
        self.maxDelayFrameCount = maxDelayFrameCount
        self.maxQP = maxQP
        self.minQP = minQP
    }

    func invalidateSession(_ rhs: VideoCodecSettings) -> Bool {
        return !(videoSize == rhs.videoSize &&
                    maxKeyFrameIntervalDuration == rhs.maxKeyFrameIntervalDuration &&
                    scalingMode == rhs.scalingMode &&
                    allowFrameReordering == rhs.allowFrameReordering &&
                    bitRateMode == rhs.bitRateMode &&
                    profileLevel == rhs.profileLevel &&
                    isHardwareEncoderEnabled == rhs.isHardwareEncoderEnabled
        )
    }

    func apply(_ codec: VideoCodec, rhs: VideoCodecSettings) {
        if bitRate != rhs.bitRate {
            let option = VTSessionOption(key: bitRateMode.key, value: NSNumber(value: bitRate))
            if let status = codec.session?.setOption(option), status != noErr {
                codec.delegate?.videoCodec(codec, errorOccurred: .failedToSetOption(status: status, option: option))
            }
//            _ = codec.session?.setOption(.init(key: .dataRateLimits, value: [(Double(bitRate) * Double(dataLimiteLate)) as CFNumber, Double(1.0) as CFNumber] as CFArray))
        }
    }

    func options(_ codec: VideoCodec) -> Set<VTSessionOption> {
        let isBaseline = profileLevel.contains("Baseline")

        var options = Set<VTSessionOption>([
            .init(key: .realTime, value: self.realtime ? kCFBooleanTrue : kCFBooleanFalse),
            .init(key: .profileLevel, value: profileLevel as NSObject),
            .init(key: bitRateMode.key, value: NSNumber(value: bitRate)),
            // It seemes that VT supports the range 0 to 30.
            .init(key: .expectedFrameRate, value: NSNumber(value: (codec.expectedFrameRate <= 30) ? codec.expectedFrameRate : 0)),
            .init(key: .maxKeyFrameIntervalDuration, value: NSNumber(value: maxKeyFrameIntervalDuration)),
            .init(key: .allowFrameReordering, value: (allowFrameReordering ?? !isBaseline) as NSObject),
            .init(key: .pixelTransferProperties, value: [
                "ScalingMode": scalingMode.rawValue
            ] as NSObject),
        ])

        if let allowTemporalCompression = self.allowTemporalCompression {
            options.insert(.init(key: .allowTemporalCompression, value: allowTemporalCompression ? kCFBooleanTrue : kCFBooleanFalse))
        }
        
        if let dataLimiteLate = self.dataLimiteLate {
            if bitRateMode == .average {
                options.insert(.init(key: .dataRateLimits, value: [(Double(bitRate) * Double(dataLimiteLate)) as CFNumber, Double(1.0) as CFNumber] as CFArray))
            }
        }

        if let maxDelayFrameCount = self.maxDelayFrameCount {
            options.insert(.init(key: .maxFrameDelayCount, value: NSNumber(value: Int(maxDelayFrameCount))))
        }
        
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            if let maxQP = self.maxQP, let minQP = self.minQP {
                options.insert(.init(key: .maxAllowedFrameQP, value: NSNumber(value: maxQP)))
                options.insert(.init(key: .minAllowedFrameQP, value: NSNumber(value: minQP)))
            }
        }

        #if os(macOS)
        if isHardwareEncoderEnabled {
            options.insert(.init(key: .encoderID, value: format.encoderID))
            options.insert(.init(key: .enableHardwareAcceleratedVideoEncoder, value: kCFBooleanTrue))
            options.insert(.init(key: .requireHardwareAcceleratedVideoEncoder, value: kCFBooleanTrue))
        }
        #endif
        if !isBaseline {
            options.insert(.init(key: .H264EntropyMode, value: kVTH264EntropyMode_CABAC))
        }
        return options
    }
}
