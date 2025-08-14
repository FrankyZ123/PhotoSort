//
//  ContentGridView.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/11/25.
//

import SwiftUI
import Photos

struct ContentGridView: View {
    @ObservedObject var access: PhotoAccess
    @Binding var selectedIndex: Int
    @Binding var showDetail: Bool
    var isSelecting: Bool = false
    @Binding var selectedAssets: Set<String>
    
    @State private var isDragging = false
    @State private var dragStartAsset: String? = nil
    @State private var lastDraggedAsset: String? = nil
    @State private var initialSelectionState: Bool = false
    @State private var longPressTriggered = false
    @State private var longPressTimer: Timer? = nil
    @State private var pressedIndex: Int? = nil
    @State private var touchStartTime: Date? = nil
    @State private var touchStartLocation: CGPoint? = nil
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private let spacing: CGFloat = 3
    
    private var columnCount: Int {
        verticalSizeClass == .compact ? 6 : 4  // 6 in landscape, 4 in portrait
    }
    
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnCount)
    }
    
    init(access: PhotoAccess, selectedIndex: Binding<Int>, showDetail: Binding<Bool>, isSelecting: Bool = false, selectedAssets: Binding<Set<String>> = .constant(Set())) {
        self.access = access
        self._selectedIndex = selectedIndex
        self._showDetail = showDetail
        self.isSelecting = isSelecting
        self._selectedAssets = selectedAssets
    }
    
    var body: some View {
        GeometryReader { geo in
            let cellSide = calculateCellSide(for: geo.size.width)
            let filteredAssets = access.filteredAssets
            
            ScrollView(showsIndicators: false) {
                if filteredAssets.isEmpty {
                    emptyStateView(height: geo.size.height)
                } else {
                    gridContent(cellSide: cellSide, filteredAssets: filteredAssets, geometry: geo)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredAssets.count)
            // Removed scrollDisabled entirely
            .onChange(of: isSelecting) { newValue in
                handleSelectionModeChange(newValue)
            }
            .onChange(of: selectedAssets) { newValue in
                handleSelectedAssetsChange(newValue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Helper Methods
    
    private func calculateCellSide(for width: CGFloat) -> CGFloat {
        let totalGaps = spacing * CGFloat(columnCount - 1)  // Dynamic based on column count
        // Match the side padding based on orientation
        let sidePadding: CGFloat = verticalSizeClass == .compact ? 12 : 16  // Less padding in landscape
        return (width - totalGaps - sidePadding) / CGFloat(columnCount)
    }
    
    private func handleSelectionModeChange(_ newValue: Bool) {
        if !newValue {
            longPressTriggered = false
            isDragging = false
            dragStartAsset = nil
            lastDraggedAsset = nil
            longPressTimer?.invalidate()
            longPressTimer = nil
            pressedIndex = nil
            touchStartTime = nil
            touchStartLocation = nil
        }
    }
    
    private func handleSelectedAssetsChange(_ newValue: Set<String>) {
        if newValue.isEmpty && longPressTriggered && !isSelecting {
            longPressTriggered = false
        }
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private func emptyStateView(height: CGFloat) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No photos to show")
                .font(.title3)
                .fontWeight(.medium)
            Text("Try adjusting your filters or selecting a different album")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(minHeight: height)
    }
    
    @ViewBuilder
    private func gridContent(cellSide: CGFloat, filteredAssets: [PHAsset], geometry: GeometryProxy) -> some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(Array(filteredAssets.enumerated()), id: \.element.localIdentifier) { idx, asset in
                SingleGridCell(
                    asset: asset,
                    index: idx,
                    cellSide: cellSide,
                    access: access,
                    isSelecting: isSelecting || longPressTriggered || !selectedAssets.isEmpty,
                    isSelected: selectedAssets.contains(asset.localIdentifier),
                    onTap: { handleTap(for: asset, at: idx) },
                    onDragChanged: { value in
                        handleCellDragChanged(value: value, asset: asset, idx: idx)
                    },
                    onDragEnded: {
                        handleCellDragEnded()
                    }
                )
            }
        }
        .padding(.horizontal, verticalSizeClass == .compact ? 6 : 8)  // Less padding in landscape
        .padding(.vertical, verticalSizeClass == .compact ? 6 : 8)  // Less padding in landscape
        .gesture(
            // Only add the drag gesture when in selection mode
            longPressTriggered ?
            DragGesture(minimumDistance: 20)  // Increased minimum distance
                .onChanged { value in
                    handleGridDragChanged(value: value, geometry: geometry, cellSide: cellSide)
                }
                .onEnded { _ in
                    handleGridDragEnded()
                }
            : nil
        )
    }
    
    // MARK: - Interaction Handlers
    
    private func handleTap(for asset: PHAsset, at index: Int) {
        if isSelecting || longPressTriggered || !selectedAssets.isEmpty {
            if selectedAssets.contains(asset.localIdentifier) {
                selectedAssets.remove(asset.localIdentifier)
                if selectedAssets.isEmpty && longPressTriggered {
                    longPressTriggered = false
                }
            } else {
                if !isSelecting && !longPressTriggered {
                    longPressTriggered = true
                }
                selectedAssets.insert(asset.localIdentifier)
            }
        } else {
            selectedIndex = index
            showDetail = true
        }
    }
    
    private func handleCellDragChanged(value: DragGesture.Value, asset: PHAsset, idx: Int) {
        if !isDragging && !longPressTriggered && pressedIndex == nil {
            pressedIndex = idx
            touchStartTime = Date()
            touchStartLocation = value.location
            
            longPressTimer?.invalidate()
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                if let startLoc = self.touchStartLocation,
                   abs(value.location.x - startLoc.x) < 10,
                   abs(value.location.y - startLoc.y) < 10 {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    
                    withAnimation(.easeInOut(duration: 0.1)) {
                        self.longPressTriggered = true
                    }
                    
                    if !self.selectedAssets.contains(asset.localIdentifier) {
                        self.selectedAssets.insert(asset.localIdentifier)
                    }
                    
                    self.isDragging = true
                    self.dragStartAsset = asset.localIdentifier
                    self.lastDraggedAsset = asset.localIdentifier
                    self.initialSelectionState = true
                }
            }
        }
    }
    
    private func handleCellDragEnded() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        pressedIndex = nil
        touchStartTime = nil
        touchStartLocation = nil
        
        if isDragging {
            isDragging = false
            dragStartAsset = nil
            lastDraggedAsset = nil
            
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
    
    private func handleGridDragChanged(value: DragGesture.Value, geometry: GeometryProxy, cellSide: CGFloat) {
        if longPressTriggered && !isDragging {
            isDragging = true
            
            if let startAsset = getAssetAt(location: value.startLocation, in: geometry, cellSide: cellSide) {
                dragStartAsset = startAsset.localIdentifier
                initialSelectionState = !selectedAssets.contains(startAsset.localIdentifier)
            }
        }
        
        if isDragging && longPressTriggered,
           let currentAsset = getAssetAt(location: value.location, in: geometry, cellSide: cellSide) {
            if currentAsset.localIdentifier != lastDraggedAsset {
                lastDraggedAsset = currentAsset.localIdentifier
                updateSelection(for: currentAsset.localIdentifier)
            }
        }
    }
    
    private func updateSelection(for assetId: String) {
        if initialSelectionState {
            if !selectedAssets.contains(assetId) {
                selectedAssets.insert(assetId)
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        } else {
            if selectedAssets.contains(assetId) {
                selectedAssets.remove(assetId)
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        }
    }
    
    private func handleGridDragEnded() {
        if isDragging {
            isDragging = false
            dragStartAsset = nil
            lastDraggedAsset = nil
            
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
        
        if longPressTriggered && selectedAssets.isEmpty {
            longPressTriggered = false
        }
    }
    
    private func getAssetAt(location: CGPoint, in geometry: GeometryProxy, cellSide: CGFloat) -> PHAsset? {
        let filteredAssets = access.filteredAssets
        
        // Adjust for padding based on orientation
        let padding: CGFloat = verticalSizeClass == .compact ? 6 : 8
        let adjustedX = location.x - padding
        let adjustedY = location.y - padding
        
        guard adjustedX >= 0 && adjustedY >= 0 else { return nil }
        
        let column = Int(adjustedX / (cellSide + spacing))
        let row = Int(adjustedY / (cellSide + spacing))
        
        guard column >= 0 && column < columnCount else { return nil }  // Use dynamic column count
        
        let index = row * columnCount + column  // Use dynamic column count
        
        guard index >= 0 && index < filteredAssets.count else { return nil }
        
        return filteredAssets[index]
    }
}

// MARK: - Single Grid Cell

struct SingleGridCell: View {
    let asset: PHAsset
    let index: Int
    let cellSide: CGFloat
    let access: PhotoAccess
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void
    
    var body: some View {
        GridCellView(
            asset: asset,
            index: index,
            side: cellSide,
            access: access,
            isSelecting: isSelecting,
            isSelected: isSelected,
            onTap: onTap
        )
        .transition(.scale.combined(with: .opacity))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged(onDragChanged)
                .onEnded { _ in onDragEnded() }
        )
    }
}
