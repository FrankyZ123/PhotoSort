//
//  PhotoAccess.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/10/25.
//

import Foundation
import Photos
import UIKit

@MainActor
final class PhotoAccess: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

    // Current grid data
    @Published var assets: [PHAsset] = []
    @Published var photoCount: Int = 0
    @Published var errorMessage: String?

    // Albums the user can pick
    @Published var collections: [PHAssetCollection] = []
    @Published var selectedCollection: PHAssetCollection? {
        didSet {
            loadAssets(in: selectedCollection)
        }
    }

    // Tags + progress
    @Published var tagStore: TagStore = .shared
    @Published private(set) var sortedCount: Int = 0
    @Published private(set) var unsortedCount: Int = 0  // Track unsorted photos
    
    // Filter properties
    @Published var activeFilters: Set<PhotoTag> = Set(PhotoTag.allCases) // Show all by default
    @Published var showUntagged: Bool = true // Show untagged photos by default

    private let imageManager = PHCachingImageManager()

    // MARK: - Filtering
    
    var filteredAssets: [PHAsset] {
        return assets.filter { asset in
            if let tag = self.tag(for: asset) {
                return activeFilters.contains(tag)
            } else {
                return showUntagged
            }
        }
    }
    
    var unsortedFilteredCount: Int {
        // Count of unsorted photos in current filtered view
        return filteredAssets.filter { asset in
            self.tag(for: asset) == nil
        }.count
    }
    
    func setFilter(_ filters: Set<PhotoTag>, showUntagged: Bool) {
        self.activeFilters = filters
        self.showUntagged = showUntagged
        updateUnsortedCount()
    }
    
    func clearFilters() {
        self.activeFilters = Set(PhotoTag.allCases)
        self.showUntagged = true
        updateUnsortedCount()
    }
    
    var isFilterActive: Bool {
        return activeFilters != Set(PhotoTag.allCases) || !showUntagged
    }

    // MARK: - Authorization

    func refreshStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAccessAndLoad() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                self.authorizationStatus = status
                guard status == .authorized || status == .limited else {
                    self.assets = []; self.photoCount = 0
                    self.collections = []; self.selectedCollection = nil
                    self.errorMessage = "Access was not granted."
                    return
                }
                self.loadCollections()
                self.loadAssets(in: nil) // default = All Photos
            }
        }
    }

    // MARK: - Collections (OPTIMIZED)

    private func loadCollections() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            var all: [PHAssetCollection] = []
            
            // User-created albums
            let userAlbums = PHAssetCollection.fetchAssetCollections(
                with: .album,
                subtype: .albumRegular,
                options: nil
            )
            userAlbums.enumerateObjects { collection, _, _ in
                all.append(collection)
            }
            
            // Smart albums
            let smartAlbumSubtypes: [PHAssetCollectionSubtype] = [
                .smartAlbumFavorites,
                .smartAlbumRecentlyAdded,
                .smartAlbumVideos,
                .smartAlbumSelfPortraits,
                .smartAlbumPanoramas,
                .smartAlbumScreenshots,
                .smartAlbumLivePhotos
            ]
            
            for subtype in smartAlbumSubtypes {
                let albums = PHAssetCollection.fetchAssetCollections(
                    with: .smartAlbum,
                    subtype: subtype,
                    options: nil
                )
                albums.enumerateObjects { collection, _, _ in
                    all.append(collection)
                }
            }
            
            // Filter empty collections in background
            let options = await self.photosOnlyOptions()
            all = all.filter {
                PHAsset.fetchAssets(in: $0, options: options).count > 0
            }
            
            // Sort by title
            all.sort { ($0.localizedTitle ?? "") < ($1.localizedTitle ?? "") }
            
            // Update on main thread
            await MainActor.run {
                self.collections = all
            }
        }
    }
    
    func refreshCollections() {
        loadCollections()
    }

    // MARK: - Assets

    private func photosOnlyOptions() -> PHFetchOptions {
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return opts
    }

    private func loadAssets(in collection: PHAssetCollection?) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            let opts = await self.photosOnlyOptions()
            let fetch: PHFetchResult<PHAsset> = (collection != nil)
                ? PHAsset.fetchAssets(in: collection!, options: opts)
                : PHAsset.fetchAssets(with: .image, options: opts)

            var tmp: [PHAsset] = []
            tmp.reserveCapacity(fetch.count)
            fetch.enumerateObjects { asset, _, _ in tmp.append(asset) }

            await MainActor.run {
                self.assets = tmp
                self.photoCount = tmp.count
                self.recomputeSortedCount()
                self.updateUnsortedCount()
            }
        }
    }

    private func recomputeSortedCount() {
        let ids = assets.map { $0.localIdentifier }
        sortedCount = ids.reduce(into: 0) { acc, id in
            if tagStore.tag(for: id) != nil { acc += 1 }
        }
        
        // Also update unsorted count
        unsortedCount = assets.count - sortedCount
    }
    
    private func updateUnsortedCount() {
        // Update the count of unsorted photos in current view
        let unsorted = unsortedFilteredCount
        unsortedCount = unsorted
        
        // Update badge manager
        BadgeManager.shared.setUnsortedCount(unsorted)
    }

    // MARK: - Tags API

    func tag(for asset: PHAsset) -> PhotoTag? {
        tagStore.tag(for: asset.localIdentifier)
    }

    func setTag(_ tag: PhotoTag?, for asset: PHAsset) {
        tagStore.setTag(tag, for: asset.localIdentifier)
        recomputeSortedCount()
        updateUnsortedCount()
    }

    // Clear tags for currently shown album/grid
    func clearTagsForCurrentAlbum() {
        let ids = assets.map { $0.localIdentifier }
        for id in ids { tagStore.setTag(nil, for: id) }
        recomputeSortedCount()
        updateUnsortedCount()
    }

    // MARK: - Process Photos (Delete tagged photos)
    
    func getPhotosToDelete() -> [PHAsset] {
        return assets.filter { asset in
            tagStore.tag(for: asset.localIdentifier) == .delete
        }
    }
    
    func processPhotos() async throws -> (deleted: Int, errors: [String]) {
        let photosToDelete = getPhotosToDelete()
        guard !photosToDelete.isEmpty else {
            return (deleted: 0, errors: [])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(photosToDelete as NSArray)
            }) { [weak self] success, error in
                DispatchQueue.main.async {
                    guard let self else {
                        continuation.resume(throwing: NSError(domain: "PhotoAccess", code: -1, userInfo: [NSLocalizedDescriptionKey: "PhotoAccess was deallocated"]))
                        return
                    }
                    
                    if success {
                        // Remove deleted photos from our local arrays and clear their tags
                        let deletedIDs = Set(photosToDelete.map { $0.localIdentifier })
                        self.assets.removeAll { deletedIDs.contains($0.localIdentifier) }
                        self.photoCount = self.assets.count
                        
                        // Clean up tags for deleted photos
                        for id in deletedIDs {
                            self.tagStore.setTag(nil, for: id)
                        }
                        
                        self.recomputeSortedCount()
                        self.updateUnsortedCount()
                        continuation.resume(returning: (deleted: photosToDelete.count, errors: []))
                    } else {
                        let errorMessage = error?.localizedDescription ?? "Unknown error occurred while deleting photos"
                        continuation.resume(returning: (deleted: 0, errors: [errorMessage]))
                    }
                }
            }
        }
    }

    // MARK: - Image requests (FULLY OPTIMIZED)

    func requestThumbnail(for asset: PHAsset, side: CGFloat, completion: @escaping (UIImage?) -> Void) {
        let scale = UIScreen.main.scale
        let target = CGSize(width: side * scale, height: side * scale)
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = false
        
        // Request directly without dispatch - PHImageManager handles threading
        imageManager.requestImage(
            for: asset,
            targetSize: target,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            // Check if this is the degraded version - skip if so
            if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                return
            }
            
            // Only dispatch to main if we have an image
            if let image = image {
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    @discardableResult
    func requestFullImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.progressHandler = nil // Avoid progress callbacks that can cause hangs
        
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        let targetSize = CGSize(
            width: screenSize.width * scale * 1.5,
            height: screenSize.height * scale * 1.5
        )
        
        // Return request ID for potential cancellation
        return imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            // Skip degraded images
            if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                return
            }
            
            // Check for errors
            if let error = info?[PHImageErrorKey] as? NSError {
                print("Image load error: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    func requestMediumImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = false
        
        let screenSize = UIScreen.main.bounds.size
        let targetSize = CGSize(
            width: screenSize.width,
            height: screenSize.height
        )
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                return
            }
            
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    // Add request cancellation support
    func cancelImageRequest(_ requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }

    // MARK: - Misc

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    var selectedTitle: String {
        selectedCollection?.localizedTitle ?? "All Photos"
    }
}
