//
//  SimpleZipArchiver.swift
//  SimRa
//
//  Created by Emil Pauls on 01.09.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation

final class SimpleZipArchiver {

    private struct Entry {
        let name: String
        let data: Data
        let crc32: UInt32
        let offset: UInt32
    }

    // MARK: - Public

    @discardableResult
    static func createZipFile(
        atPath path: String,
        withFilesAtPaths filePaths: [String]
    ) -> Bool {

        let fileManager = FileManager.default
        let zipURL = URL(fileURLWithPath: path)

        do {
            if fileManager.fileExists(atPath: path) {
                try fileManager.removeItem(at: zipURL)
            }

            var entries: [Entry] = []
            var zipData = Data()

            for filePath in filePaths {
                guard fileManager.fileExists(atPath: filePath) else {
                    continue
                }

                var isDirectory: ObjCBool = false

                guard fileManager.fileExists(
                    atPath: filePath,
                    isDirectory: &isDirectory
                ), !isDirectory.boolValue else {
                    continue
                }

                let fileURL = URL(fileURLWithPath: filePath)
                let data = try Data(contentsOf: fileURL)

                let fileName = fileURL.lastPathComponent
                let nameData = Data(fileName.utf8)

                let crc = CRC32.checksum(data)
                let offset = UInt32(zipData.count)

                // Local file header
                zipData.appendUInt32(0x04034b50)
                zipData.appendUInt16(20)       // Version needed
                zipData.appendUInt16(0)        // Flags
                zipData.appendUInt16(0)        // Compression: stored
                zipData.appendUInt16(0)        // Modification time
                zipData.appendUInt16(0)        // Modification date
                zipData.appendUInt32(crc)
                zipData.appendUInt32(UInt32(data.count))
                zipData.appendUInt32(UInt32(data.count))
                zipData.appendUInt16(UInt16(nameData.count))
                zipData.appendUInt16(0)        // Extra field length
                zipData.append(nameData)
                zipData.append(data)

                entries.append(
                    Entry(
                        name: fileName,
                        data: data,
                        crc32: crc,
                        offset: offset
                    )
                )
            }

            guard !entries.isEmpty else {
                return false
            }

            let centralDirectoryOffset = UInt32(zipData.count)

            // Central directory
            for entry in entries {
                let nameData = Data(entry.name.utf8)

                zipData.appendUInt32(0x02014b50)
                zipData.appendUInt16(20)       // Version made by
                zipData.appendUInt16(20)       // Version needed
                zipData.appendUInt16(0)        // Flags
                zipData.appendUInt16(0)        // Compression
                zipData.appendUInt16(0)        // Modification time
                zipData.appendUInt16(0)        // Modification date
                zipData.appendUInt32(entry.crc32)
                zipData.appendUInt32(UInt32(entry.data.count))
                zipData.appendUInt32(UInt32(entry.data.count))
                zipData.appendUInt16(UInt16(nameData.count))
                zipData.appendUInt16(0)        // Extra length
                zipData.appendUInt16(0)        // Comment length
                zipData.appendUInt16(0)        // Disk number
                zipData.appendUInt16(0)        // Internal attributes
                zipData.appendUInt32(0)        // External attributes
                zipData.appendUInt32(entry.offset)
                zipData.append(nameData)
            }

            let centralDirectorySize =
                UInt32(zipData.count) - centralDirectoryOffset

            // End of central directory
            zipData.appendUInt32(0x06054b50)
            zipData.appendUInt16(0) // Disk number
            zipData.appendUInt16(0) // Central directory disk
            zipData.appendUInt16(UInt16(entries.count))
            zipData.appendUInt16(UInt16(entries.count))
            zipData.appendUInt32(centralDirectorySize)
            zipData.appendUInt32(centralDirectoryOffset)
            zipData.appendUInt16(0) // Comment length

            try zipData.write(to: zipURL, options: .atomic)

            return true

        } catch {
            print("SimpleZipArchiver error:", error)
            return false
        }
    }
}

// MARK: - CRC32

private enum CRC32 {

    static func checksum(_ data: Data) -> UInt32 {

        var crc: UInt32 = 0xFFFFFFFF

        for byte in data {
            crc ^= UInt32(byte)

            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
        }

        return crc ^ 0xFFFFFFFF
    }
}

// MARK: - Data helpers

private extension Data {

    mutating func appendUInt16(_ value: UInt16) {
        var value = value.littleEndian
        Swift.withUnsafeBytes(of: &value) {
            append(contentsOf: $0)
        }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var value = value.littleEndian
        Swift.withUnsafeBytes(of: &value) {
            append(contentsOf: $0)
        }
    }
}
