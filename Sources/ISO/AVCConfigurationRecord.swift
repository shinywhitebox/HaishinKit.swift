import AVFoundation
import VideoToolbox

// MARK: -
/*
 - seealso: ISO/IEC 14496-15 2010
 */
struct AVCConfigurationRecord {
    static func getData(_ formatDescription: CMFormatDescription?) -> Data? {
        guard let formatDescription = formatDescription else {
            return nil
        }
        if let atoms: NSDictionary = CMFormatDescriptionGetExtension(formatDescription, extensionKey: "SampleDescriptionExtensionAtoms" as CFString) as? NSDictionary {
            return atoms["avcC"] as? Data
        }
        return nil
    }

    static let reserveLengthSizeMinusOne: UInt8 = 0x3F
    static let reserveNumOfSequenceParameterSets: UInt8 = 0xE0
    static let reserveChromaFormat: UInt8 = 0xFC
    static let reserveBitDepthLumaMinus8: UInt8 = 0xF8
    static let reserveBitDepthChromaMinus8 = 0xF8

    var configurationVersion: UInt8 = 1
    var AVCProfileIndication: UInt8 = 0
    var profileCompatibility: UInt8 = 0
    var AVCLevelIndication: UInt8 = 0
    var lengthSizeMinusOneWithReserved: UInt8 = 0
    var numOfSequenceParameterSetsWithReserved: UInt8 = 0
    var sequenceParameterSets: [[UInt8]] = []
    var pictureParameterSets: [[UInt8]] = []

    var chromaFormatWithReserve: UInt8 = 0
    var bitDepthLumaMinus8WithReserve: UInt8 = 0
    var bitDepthChromaMinus8WithReserve: UInt8 = 0
    var sequenceParameterSetExt: [[UInt8]] = []

    var naluLength: Int32 {
        Int32((lengthSizeMinusOneWithReserved >> 6) + 1)
    }

    init() {
    }

    init(data: Data) {
        self.data = data
    }

    func createFormatDescription(_ formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>) -> OSStatus {
        sequenceParameterSets[0].withUnsafeBufferPointer { sps -> OSStatus in
            pictureParameterSets[0].withUnsafeBufferPointer { pps -> OSStatus in
                let parameterSetPointers: [UnsafePointer<UInt8>] = [
                    sps.baseAddress!, pps.baseAddress!
                ]
                let parameterSetSizes: [Int] = [
                    sps.count,
                    pps.count
                ]
                return parameterSetPointers.withUnsafeBufferPointer { paramSet in
                    parameterSetSizes.withUnsafeBufferPointer { paramSizes in
                        CMVideoFormatDescriptionCreateFromH264ParameterSets(
                                allocator: kCFAllocatorDefault,
                                parameterSetCount: 2,
                                parameterSetPointers: paramSet.baseAddress!,
                                parameterSetSizes: paramSizes.baseAddress!,
                                nalUnitHeaderLength: naluLength,
                                formatDescriptionOut: formatDescriptionOut
                        )
                    }
                }
            }
        }
    }
}

extension AVCConfigurationRecord: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            let buffer = ByteArray()
                    .writeUInt8(configurationVersion)
                    .writeUInt8(AVCProfileIndication)
                    .writeUInt8(profileCompatibility)
                    .writeUInt8(AVCLevelIndication)
                    .writeUInt8(lengthSizeMinusOneWithReserved)
                    .writeUInt8(numOfSequenceParameterSetsWithReserved)
            for i in 0..<sequenceParameterSets.count {
                buffer
                        .writeUInt16(UInt16(sequenceParameterSets[i].count))
                        .writeBytes(Data(sequenceParameterSets[i]))
            }
            buffer.writeUInt8(UInt8(pictureParameterSets.count))
            for i in 0..<pictureParameterSets.count {
                buffer
                        .writeUInt16(UInt16(pictureParameterSets[i].count))
                        .writeBytes(Data(pictureParameterSets[i]))
            }
            return buffer.data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                configurationVersion = try buffer.readUInt8()
                AVCProfileIndication = try buffer.readUInt8()
                profileCompatibility = try buffer.readUInt8()
                AVCLevelIndication = try buffer.readUInt8()
                lengthSizeMinusOneWithReserved = try buffer.readUInt8()
                numOfSequenceParameterSetsWithReserved = try buffer.readUInt8()
                let numOfSequenceParameterSets: UInt8 = numOfSequenceParameterSetsWithReserved & ~AVCConfigurationRecord.reserveNumOfSequenceParameterSets
                for _ in 0..<numOfSequenceParameterSets {
                    let length = Int(try buffer.readUInt16())
                    sequenceParameterSets.append(try buffer.readBytes(length).bytes)
                }
                let numPictureParameterSets: UInt8 = try buffer.readUInt8()
                for _ in 0..<numPictureParameterSets {
                    let length = Int(try buffer.readUInt16())
                    pictureParameterSets.append(try buffer.readBytes(length).bytes)
                }
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

extension AVCConfigurationRecord: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
