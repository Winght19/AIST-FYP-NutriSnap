import Foundation
import SwiftData
import UIKit

final class FoodLogImageStore {
    static let shared = FoodLogImageStore()

    private let fileManager = FileManager.default
    private let directoryName = "FoodLogImages"

    private init() {}

    func save(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let fileName = "\(UUID().uuidString).jpg"
        let destinationURL = try imagesDirectoryURL().appendingPathComponent(fileName)
        try data.write(to: destinationURL, options: .atomic)
        return fileName
    }

    func image(for storedPath: String?) -> UIImage? {
        guard let url = resolveURL(for: storedPath) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func deleteImage(at storedPath: String?) {
        guard let url = resolveURL(for: storedPath) else { return }
        try? fileManager.removeItem(at: url)
    }

    @MainActor
    func reconcileStorage(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<FoodLog>()
        guard let logs = try? modelContext.fetch(descriptor) else { return }

        var referencedFileNames = Set<String>()
        var didChangeLogs = false

        for log in logs {
            guard let storedPath = log.imagePath, !storedPath.isEmpty else { continue }

            if isRelativeManagedPath(storedPath) {
                referencedFileNames.insert(storedPath)
                continue
            }

            let legacyURL = URL(fileURLWithPath: storedPath)
            let targetFileName = legacyURL.lastPathComponent.isEmpty ? "\(UUID().uuidString).jpg" : legacyURL.lastPathComponent
            let targetURL: URL

            do {
                targetURL = try imagesDirectoryURL().appendingPathComponent(targetFileName)
            } catch {
                continue
            }

            if fileManager.fileExists(atPath: legacyURL.path) {
                if !fileManager.fileExists(atPath: targetURL.path) {
                    do {
                        try fileManager.copyItem(at: legacyURL, to: targetURL)
                    } catch {
                        continue
                    }
                }

                if legacyURL.path != targetURL.path {
                    try? fileManager.removeItem(at: legacyURL)
                }

                log.imagePath = targetFileName
                referencedFileNames.insert(targetFileName)
                didChangeLogs = true
            } else if fileManager.fileExists(atPath: targetURL.path) {
                log.imagePath = targetFileName
                referencedFileNames.insert(targetFileName)
                didChangeLogs = true
            } else {
                log.imagePath = nil
                didChangeLogs = true
            }
        }

        cleanupOrphanedManagedImages(referencedFileNames: referencedFileNames)

        if didChangeLogs {
            try? modelContext.save()
        }
    }

    private func resolveURL(for storedPath: String?) -> URL? {
        guard let storedPath, !storedPath.isEmpty else { return nil }

        if isRelativeManagedPath(storedPath) {
            let url = try? imagesDirectoryURL().appendingPathComponent(storedPath)
            guard let url, fileManager.fileExists(atPath: url.path) else { return nil }
            return url
        }

        let legacyURL = URL(fileURLWithPath: storedPath)
        if fileManager.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }

        let fallbackURL = try? imagesDirectoryURL().appendingPathComponent(legacyURL.lastPathComponent)
        guard let fallbackURL, fileManager.fileExists(atPath: fallbackURL.path) else { return nil }
        return fallbackURL
    }

    private func managedURL(for storedPath: String?) -> URL? {
        guard let storedPath, !storedPath.isEmpty else { return nil }

        let fileName = isRelativeManagedPath(storedPath)
            ? storedPath
            : URL(fileURLWithPath: storedPath).lastPathComponent

        guard !fileName.isEmpty else { return nil }
        return try? imagesDirectoryURL().appendingPathComponent(fileName)
    }

    private func imagesDirectoryURL() throws -> URL {
        let baseURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = baseURL.appendingPathComponent(directoryName, isDirectory: true)

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directoryURL
    }

    private func cleanupOrphanedManagedImages(referencedFileNames: Set<String>) {
        guard let directoryURL = try? imagesDirectoryURL(),
              let fileURLs = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
              ) else { return }

        for fileURL in fileURLs where !referencedFileNames.contains(fileURL.lastPathComponent) {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private func isRelativeManagedPath(_ path: String) -> Bool {
        !path.contains("/") && !path.contains(":")
    }
}
