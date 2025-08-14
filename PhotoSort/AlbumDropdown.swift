//
//  AlbumDropdown.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/11/25.
//

import SwiftUI

// MARK: - Album Dropdown

struct AlbumDropdown: View {
    @ObservedObject var access: PhotoAccess
    
    var body: some View {
        Menu {
            Button {
                access.selectedCollection = nil
            } label: {
                Label("All Photos", systemImage: access.selectedCollection == nil ? "checkmark" : "photo.on.rectangle.angled")
            }
            if !access.collections.isEmpty { Divider() }
            ForEach(access.collections, id: \.localIdentifier) { collection in
                Button { access.selectedCollection = collection } label: {
                    let title = collection.localizedTitle ?? "Untitled"
                    HStack {
                        Text(title)
                        if access.selectedCollection?.localIdentifier == collection.localIdentifier {
                            Spacer(); Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .imageScale(.medium)
                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .onTapGesture {
            access.refreshCollections()
        }
    }
}

// MARK: - Actions Dropdown

struct ActionsDropdown: View {
    @ObservedObject var access: PhotoAccess
    @Binding var isSelecting: Bool
    var selectedCount: Int
    @Binding var showFilterView: Bool
    @Binding var showClearConfirm: Bool
    @Binding var showProcessConfirm: Bool
    var isProcessing: Bool
    
    var body: some View {
        Menu {
            Button {
                showClearConfirm = true
            } label: {
                Label("Reset Tags", systemImage: "arrow.clockwise")
            }
            
            Divider()
            
            Button {
                showProcessConfirm = true
            } label: {
                Label("Process Photos", systemImage: "trash")
            }
            .disabled(access.getPhotosToDelete().isEmpty)
        } label: {
            HStack(spacing: 6) {
                if isSelecting {
                    Text("\(selectedCount) selected")
                        .font(.headline)
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.medium)
                }
                
                if access.isFilterActive && !isSelecting {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }
}

// MARK: - Progress Bar View

struct ProgressBarView: View {
    @ObservedObject var access: PhotoAccess
    var isVertical: Bool = false
    
    var body: some View {
        if isVertical {
            verticalProgressBar
        } else {
            horizontalProgressBar
        }
    }
    
    private var horizontalProgressBar: some View {
        GeometryReader { geo in
            VStack(spacing: 4) {
                // Bar chart showing tag distribution
                let filteredAssets = access.filteredAssets
                let keepCount = filteredAssets.filter { access.tag(for: $0) == .keep }.count
                let deleteCount = filteredAssets.filter { access.tag(for: $0) == .delete }.count
                let unsureCount = filteredAssets.filter { access.tag(for: $0) == .unsure }.count
                let untaggedCount = filteredAssets.filter { access.tag(for: $0) == nil }.count
                let totalFiltered = max(filteredAssets.count, 1) // Prevent division by zero
                
                HStack(spacing: 0) {
                    // Keep bar
                    if keepCount > 0 {
                        Rectangle()
                            .fill(.green)
                            .frame(width: CGFloat(keepCount) / CGFloat(totalFiltered) * geo.size.width)
                    }
                    
                    // Delete bar
                    if deleteCount > 0 {
                        Rectangle()
                            .fill(.red)
                            .frame(width: CGFloat(deleteCount) / CGFloat(totalFiltered) * geo.size.width)
                    }
                    
                    // Unsure bar
                    if unsureCount > 0 {
                        Rectangle()
                            .fill(.orange)
                            .frame(width: CGFloat(unsureCount) / CGFloat(totalFiltered) * geo.size.width)
                    }
                    
                    // Untagged bar
                    if untaggedCount > 0 {
                        Rectangle()
                            .fill(.gray.opacity(0.5))
                            .frame(width: CGFloat(untaggedCount) / CGFloat(totalFiltered) * geo.size.width)
                    }
                }
                .frame(width: geo.size.width, height: 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(3)
                .clipped()
                
                // Count display
                HStack(spacing: 8) {
                    let sortedInFiltered = filteredAssets.filter { access.tag(for: $0) != nil }.count
                    
                    Text("\(sortedInFiltered)/\(totalFiltered)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    
                    if access.isFilterActive && totalFiltered != access.photoCount {
                        Text("of \(access.photoCount) total")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 30) // Fixed height for the progress view
    }
    
    private var verticalProgressBar: some View {
        GeometryReader { geo in
            HStack(spacing: 4) {
                // Vertical bar chart
                let filteredAssets = access.filteredAssets
                let keepCount = filteredAssets.filter { access.tag(for: $0) == .keep }.count
                let deleteCount = filteredAssets.filter { access.tag(for: $0) == .delete }.count
                let unsureCount = filteredAssets.filter { access.tag(for: $0) == .unsure }.count
                let untaggedCount = filteredAssets.filter { access.tag(for: $0) == nil }.count
                let totalFiltered = max(filteredAssets.count, 1) // Prevent division by zero
                
                VStack(spacing: 0) {
                    // Untagged bar (top)
                    if untaggedCount > 0 {
                        Rectangle()
                            .fill(.gray.opacity(0.5))
                            .frame(height: CGFloat(untaggedCount) / CGFloat(totalFiltered) * geo.size.height)
                    }
                    
                    // Unsure bar
                    if unsureCount > 0 {
                        Rectangle()
                            .fill(.orange)
                            .frame(height: CGFloat(unsureCount) / CGFloat(totalFiltered) * geo.size.height)
                    }
                    
                    // Delete bar
                    if deleteCount > 0 {
                        Rectangle()
                            .fill(.red)
                            .frame(height: CGFloat(deleteCount) / CGFloat(totalFiltered) * geo.size.height)
                    }
                    
                    // Keep bar (bottom)
                    if keepCount > 0 {
                        Rectangle()
                            .fill(.green)
                            .frame(height: CGFloat(keepCount) / CGFloat(totalFiltered) * geo.size.height)
                    }
                }
                .frame(width: 8, height: geo.size.height)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
                .clipped()
                
                // Count display (rotated)
                VStack(spacing: 4) {
                    let sortedInFiltered = filteredAssets.filter { access.tag(for: $0) != nil }.count
                    
                    Text("\(sortedInFiltered)/\(totalFiltered)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    
                    if access.isFilterActive && totalFiltered != access.photoCount {
                        Text("of \(access.photoCount)")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .monospacedDigit()
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
