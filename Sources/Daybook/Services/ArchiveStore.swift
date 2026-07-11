import Compression
import Foundation

protocol ArchiveStore {
    func listEntries() throws -> [SealedDiaryEntry]
    func entry(for date: Date) throws -> SealedDiaryEntry?
    func create(from draft: DiaryEntryDraft) throws -> SealedDiaryEntry
    func readPayload(for entry: SealedDiaryEntry) throws -> ArchivedEntryPayload
    func export(entry: SealedDiaryEntry, to destinationURL: URL) throws
}

final class LocalArchiveStore: ArchiveStore {
    private let calendar: Calendar
    private let fileManager: FileManager
    private let rootURL: URL
    private let archiveDirectoryURL: URL
    private let indexURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        calendar: Calendar = .current,
        fileManager: FileManager = .default,
        rootURL: URL? = nil
    ) {
        self.calendar = calendar
        self.fileManager = fileManager

        let baseRoot: URL
        if let rootURL {
            baseRoot = rootURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            baseRoot = appSupport.appendingPathComponent("RetroDiary", isDirectory: true)
        }

        self.rootURL = baseRoot
        self.archiveDirectoryURL = baseRoot.appendingPathComponent("Entries", isDirectory: true)
        self.indexURL = baseRoot.appendingPathComponent("entry-index.json")

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        try? ensureStorage()
    }

    func listEntries() throws -> [SealedDiaryEntry] {
        let entries = try loadIndex().entries
        return entries.sorted { $0.date > $1.date }
    }

    func entry(for date: Date) throws -> SealedDiaryEntry? {
        let key = date.diaryKey(calendar: calendar)
        return try loadIndex().entries.first { $0.date.diaryKey(calendar: calendar) == key }
    }

    func create(from draft: DiaryEntryDraft) throws -> SealedDiaryEntry {
        let text = draft.text.trimmed()
        guard !text.isEmpty else { throw DiaryError.emptyText }

        try ensureStorage()
        var index = try loadIndex()
        let key = draft.date.diaryKey(calendar: calendar)

        guard index.entries.contains(where: { $0.date.diaryKey(calendar: calendar) == key }) == false else {
            throw DiaryError.alreadySealed
        }

        let payload = ArchivedEntryPayload(
            id: UUID(),
            date: calendar.startOfDay(for: draft.date),
            sealedAt: Date(),
            text: text,
            moodCard: draft.moodCard
        )
        let archiveFileName = "\(key)-\(payload.id.uuidString).rdiary"
        let archiveURL = archiveDirectoryURL.appendingPathComponent(archiveFileName)
        let compressedData = try compressPayload(payload)
        try compressedData.write(to: archiveURL, options: .atomic)

        let entry = SealedDiaryEntry(
            id: payload.id,
            date: payload.date,
            sealedAt: payload.sealedAt,
            archiveFileName: archiveFileName,
            archiveByteCount: compressedData.count,
            preview: text.previewText(),
            moodCard: draft.moodCard
        )

        index.entries.append(entry)
        try saveIndex(index)
        return entry
    }

    func readPayload(for entry: SealedDiaryEntry) throws -> ArchivedEntryPayload {
        let archiveURL = archiveDirectoryURL.appendingPathComponent(entry.archiveFileName)
        guard fileManager.fileExists(atPath: archiveURL.path) else {
            throw DiaryError.entryNotFound
        }

        let compressedData = try Data(contentsOf: archiveURL)
        return try decompressPayload(compressedData)
    }

    func export(entry: SealedDiaryEntry, to destinationURL: URL) throws {
        let sourceURL = archiveDirectoryURL.appendingPathComponent(entry.archiveFileName)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw DiaryError.entryNotFound
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw DiaryError.exportFailed
        }
    }

    private func ensureStorage() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: archiveDirectoryURL, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: indexURL.path) == false {
            try saveIndex(EntryIndex(entries: []))
        }
    }

    private func loadIndex() throws -> EntryIndex {
        try ensureStorage()
        let data = try Data(contentsOf: indexURL)
        return try decoder.decode(EntryIndex.self, from: data)
    }

    private func saveIndex(_ index: EntryIndex) throws {
        let data = try encoder.encode(index)
        try data.write(to: indexURL, options: .atomic)
    }

    private func compressPayload(_ payload: ArchivedEntryPayload) throws -> Data {
        let data = try encoder.encode(payload)
        return try CompressionCodec.compress(data)
    }

    private func decompressPayload(_ data: Data) throws -> ArchivedEntryPayload {
        let decompressed = try CompressionCodec.decompress(data)
        return try decoder.decode(ArchivedEntryPayload.self, from: decompressed)
    }
}

private struct EntryIndex: Codable {
    var entries: [SealedDiaryEntry]
}

enum CompressionCodec {
    static func compress(_ data: Data) throws -> Data {
        guard data.isEmpty == false else { return Data() }

        let destinationCapacity = max(1024, data.count * 2)
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationCapacity)
        defer { destinationBuffer.deallocate() }

        let compressedCount = data.withUnsafeBytes { rawBuffer -> Int in
            guard let source = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_encode_buffer(
                destinationBuffer,
                destinationCapacity,
                source,
                data.count,
                nil,
                COMPRESSION_LZFSE
            )
        }

        guard compressedCount > 0 else { throw CocoaError(.fileWriteUnknown) }

        var header = withUnsafeBytes(of: UInt64(data.count).bigEndian) { Data($0) }
        header.append(destinationBuffer, count: compressedCount)
        return header
    }

    static func decompress(_ data: Data) throws -> Data {
        guard data.count >= MemoryLayout<UInt64>.size else { throw CocoaError(.coderReadCorrupt) }

        let header = data.prefix(MemoryLayout<UInt64>.size)
        let expectedCount = header.withUnsafeBytes { rawBuffer in
            rawBuffer.load(as: UInt64.self).bigEndian
        }
        let compressedPayload = data.dropFirst(MemoryLayout<UInt64>.size)
        let destinationCapacity = Int(expectedCount)
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationCapacity)
        defer { destinationBuffer.deallocate() }

        let decompressedCount = compressedPayload.withUnsafeBytes { rawBuffer -> Int in
            guard let source = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                destinationBuffer,
                destinationCapacity,
                source,
                compressedPayload.count,
                nil,
                COMPRESSION_LZFSE
            )
        }

        guard decompressedCount == destinationCapacity else { throw CocoaError(.coderReadCorrupt) }
        return Data(bytes: destinationBuffer, count: decompressedCount)
    }
}
