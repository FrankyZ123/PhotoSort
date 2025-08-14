//
//  TagStore.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/10/25.
//

import Foundation

enum PhotoTag: String, Codable, CaseIterable {
    case keep
    case delete
    case unsure
}

@MainActor
final class TagStore: ObservableObject {
    static let shared = TagStore()
    @Published private(set) var tags: [String: PhotoTag] = [:]   // key = PHAsset.localIdentifier

    private let url: URL
    private var saveTask: Task<Void, Never>?

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PhotoSort", conformingTo: .folder)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("tags_v1.json")
        load()
    }

    func tag(for localIdentifier: String) -> PhotoTag? {
        tags[localIdentifier]
    }

    func setTag(_ tag: PhotoTag?, for localIdentifier: String) {
        if let tag {
            tags[localIdentifier] = tag
        } else {
            tags.removeValue(forKey: localIdentifier)
        }
        save()
    }

    func removeAll(forMissing existingIDs: Set<String>) {
        let stale = tags.keys.filter { !existingIDs.contains($0) }
        guard !stale.isEmpty else { return }
        stale.forEach { tags.removeValue(forKey: $0) }
        save()
    }

    // MARK: - Persistence (OPTIMIZED)
    
    private func load() {
        // Load asynchronously to avoid blocking main thread during init
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            guard let data = try? Data(contentsOf: self.url) else { return }
            if let decoded = try? JSONDecoder().decode([String: PhotoTag].self, from: data) {
                await MainActor.run {
                    self.tags = decoded
                }
            }
        }
    }

    private func save() {
        // Cancel any pending save
        saveTask?.cancel()
        
        // Capture current state
        let tagsToSave = self.tags
        let saveURL = self.url
        
        // Debounce saves - wait a bit in case more changes are coming
        saveTask = Task.detached(priority: .background) {
            // Small delay to batch multiple rapid changes
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Check if task was cancelled
            if Task.isCancelled { return }
            
            do {
                let data = try JSONEncoder().encode(tagsToSave)
                try data.write(to: saveURL, options: .atomic)
            } catch {
                print("Failed to save tags: \(error)")
            }
        }
    }
}
