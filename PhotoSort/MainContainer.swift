//
//  MainContainerView.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/11/25.
//

import SwiftUI
import Photos

struct MainContainerView: View {
    @StateObject private var access = PhotoAccess()
    @EnvironmentObject var badgeManager: BadgeManager
    
    @State private var showDetail = false
    @State private var selectedIndex = 0
    
    // Multi-select state
    @State private var isSelecting = false
    @State private var selectedAssets: Set<String> = []
    
    // Shared toolbar state
    @State private var showClearConfirm = false
    @State private var showProcessConfirm = false
    @State private var isProcessing = false
    @State private var processResult: (deleted: Int, errors: [String])? = nil
    @State private var showProcessAlert = false
    
    // Tagging state and feedback
    @State private var flash: TaggingDecision?
    @State private var flashTask: Task<Void, Never>?
    private let successHaptic = UINotificationFeedbackGenerator()
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        Group {
            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            access.refreshStatus()
            access.requestAccessAndLoad()
            successHaptic.prepare()
        }
        .onChange(of: access.unsortedCount) { newCount in
            // Update badge manager when unsorted count changes
            badgeManager.setUnsortedCount(newCount)
        }
    }
    
    // MARK: - Layout Components
    
    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            // Left toolbar
            PhotoSortToolbar(
                access: access,
                showClearConfirm: $showClearConfirm,
                showProcessConfirm: $showProcessConfirm,
                isProcessing: $isProcessing,
                processResult: $processResult,
                showProcessAlert: $showProcessAlert,
                onProcessPhotos: processPhotos,
                isVertical: true,
                isSelecting: $isSelecting,
                selectedCount: selectedAssets.count
            )
            .frame(maxHeight: .infinity)
            
            // Main content
            mainContent
            
            // Right toolbar - always visible
            TaggingToolbar(
                access: access,
                selectedIndex: $selectedIndex,
                showDetail: $showDetail,
                onTag: handleTagging,
                isVertical: true,
                isSelecting: isSelecting,
                selectedCount: selectedAssets.count,
                onBulkTag: handleBulkTagging,
                onCancelSelection: {
                    // Clear all selections (but stay in selection mode)
                    selectedAssets.removeAll()
                },
                onExitSelection: {
                    // Exit selection mode entirely and go back to grid
                    selectedAssets.removeAll()
                    isSelecting = false
                }
            )
            .frame(maxHeight: .infinity)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.3), value: isSelecting)
    }
    
    private var portraitLayout: some View {
        VStack(spacing: 0) {
            // Top toolbar
            PhotoSortToolbar(
                access: access,
                showClearConfirm: $showClearConfirm,
                showProcessConfirm: $showProcessConfirm,
                isProcessing: $isProcessing,
                processResult: $processResult,
                showProcessAlert: $showProcessAlert,
                onProcessPhotos: processPhotos,
                isVertical: false,
                isSelecting: $isSelecting,
                selectedCount: selectedAssets.count
            )
            
            // Main content
            mainContent
            
            // Bottom toolbar - always visible
            TaggingToolbar(
                access: access,
                selectedIndex: $selectedIndex,
                showDetail: $showDetail,
                onTag: handleTagging,
                isVertical: false,
                isSelecting: isSelecting,
                selectedCount: selectedAssets.count,
                onBulkTag: handleBulkTagging,
                onCancelSelection: {
                    // Clear all selections (but stay in selection mode)
                    selectedAssets.removeAll()
                },
                onExitSelection: {
                    // Exit selection mode entirely and go back to grid
                    selectedAssets.removeAll()
                    isSelecting = false
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.3), value: isSelecting)
    }
    
    private var mainContent: some View {
        ZStack {
            // Grid View - keep it rendered but hidden when detail is shown
            ContentGridView(
                access: access,
                selectedIndex: $selectedIndex,
                showDetail: $showDetail,
                isSelecting: isSelecting,
                selectedAssets: $selectedAssets
            )
            .opacity(showDetail ? 0 : 1) // Hide but don't remove
            
            // Detail View - appear instantly without animation
            if showDetail && !isSelecting {
                PhotoDetailView(
                    assets: access.filteredAssets,
                    index: $selectedIndex,
                    access: access,
                    showDetail: $showDetail
                )
                .zIndex(1)
                // No transition - just appear/disappear instantly
            }
            
            // Flash banner
            FlashBannerView(flash: flash)
        }
        .animation(nil, value: showDetail) // Disable animation for showDetail changes
    }
    
    // MARK: - Tagging Handlers
    
    private func handleTagging(_ decision: TaggingDecision) {
        let targetAsset: PHAsset?
        
        if showDetail {
            targetAsset = access.filteredAssets[safe: selectedIndex]
        } else {
            targetAsset = access.filteredAssets.first { access.tag(for: $0) == nil }
            if let asset = targetAsset,
               let index = access.filteredAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
                selectedIndex = index
            }
        }
        
        guard let asset = targetAsset else { return }
        
        // Store the next asset BEFORE applying the tag (in case filtering removes current asset)
        var nextAsset: PHAsset? = nil
        if showDetail && selectedIndex < access.filteredAssets.count - 1 {
            nextAsset = access.filteredAssets[selectedIndex + 1]
        }
        
        // Apply the tag (even if updating an existing tag)
        switch decision {
        case .keep:     access.setTag(.keep, for: asset)
        case .delete:   access.setTag(.delete, for: asset)
        case .unsure:   access.setTag(.unsure, for: asset)
        }
        
        // Provide feedback
        provideFeedback(for: decision)
        
        // Smart auto-advance in detail view
        if showDetail {
            advanceToNextSmart(previousNextAsset: nextAsset)
        }
    }
    
    private func handleBulkTagging(_ decision: TaggingDecision) {
        guard !selectedAssets.isEmpty else { return }
        
        // Batch the updates
        Task { @MainActor in
            // Apply tag to all selected assets
            for assetId in selectedAssets {
                if let asset = access.assets.first(where: { $0.localIdentifier == assetId }) {
                    switch decision {
                    case .keep:     access.setTag(.keep, for: asset)
                    case .delete:   access.setTag(.delete, for: asset)
                    case .unsure:   access.setTag(.unsure, for: asset)
                    }
                }
            }
            
            // Clear selection and exit selection mode
            selectedAssets.removeAll()
            isSelecting = false
            
            // Provide feedback
            provideFeedback(for: decision, duration: 1000)
        }
    }
    
    // MARK: - Helper Methods
    
    private func provideFeedback(for decision: TaggingDecision, duration: Int = 750) {
        successHaptic.notificationOccurred(.success)
        flashTask?.cancel()
        
        withAnimation(.easeIn(duration: 0.15)) { flash = decision }
        
        flashTask = Task {
            try? await Task.sleep(for: .milliseconds(duration))
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        flash = nil
                    }
                }
            }
        }
    }
    
    private func advanceToNext() {
        if selectedIndex < access.filteredAssets.count - 1 {
            // Immediate advancement with smooth animation
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedIndex += 1
            }
        }
    }
    
    private func advanceToNextSmart(previousNextAsset: PHAsset?) {
        // If we had a next asset before tagging, find its new index
        if let nextAsset = previousNextAsset,
           let newIndex = access.filteredAssets.firstIndex(where: { $0.localIdentifier == nextAsset.localIdentifier }) {
            // The next asset is still in the filtered list, go to it
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedIndex = newIndex
            }
        } else {
            // The next asset was filtered out OR we were at the end
            // Stay at the same index (which now shows a different photo due to filtering)
            // OR move to the next available photo if current index is now out of bounds
            if selectedIndex >= access.filteredAssets.count && access.filteredAssets.count > 0 {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedIndex = access.filteredAssets.count - 1
                }
            }
            // Otherwise keep the same index - a new photo will slide into this position
        }
    }
    
    private func processPhotos() {
        isProcessing = true
        
        Task {
            do {
                let result = try await access.processPhotos()
                await MainActor.run {
                    processResult = result
                    showProcessAlert = true
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    processResult = (deleted: 0, errors: [error.localizedDescription])
                    showProcessAlert = true
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Extensions

private extension Array {
    subscript(safe i: Index) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}
