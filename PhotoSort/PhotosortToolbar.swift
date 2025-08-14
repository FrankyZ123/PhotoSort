//
//  PhotoSortToolbar.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/11/25.
//

import SwiftUI

struct PhotoSortToolbar: View {
    @ObservedObject var access: PhotoAccess
    @Binding var showClearConfirm: Bool
    @Binding var showProcessConfirm: Bool
    @Binding var isProcessing: Bool
    @Binding var processResult: (deleted: Int, errors: [String])?
    @Binding var showProcessAlert: Bool
    let onProcessPhotos: () -> Void
    var isVertical: Bool = false
    var isSelecting: Binding<Bool>?
    var selectedCount: Int = 0
    
    @State private var localIsSelecting: Bool = false
    @State private var showFilterView = false
    
    private var selectingBinding: Binding<Bool> {
        isSelecting ?? $localIsSelecting
    }
    
    var body: some View {
        Group {
            if isVertical {
                verticalLayout
            } else {
                horizontalLayout
            }
        }
        .sheet(isPresented: $showFilterView) {
            FilterView(access: access, isPresented: $showFilterView)
        }
        .alert("Re-sort this album?", isPresented: $showClearConfirm) {
            Button("Clear Tags", role: .destructive) { access.clearTagsForCurrentAlbum() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes all tags you've set for the photos currently shown so you can re-sort them. Photos themselves are unaffected.")
        }
        .alert("Delete tagged photos?", isPresented: $showProcessConfirm) {
            Button("Delete \(access.getPhotosToDelete().count) Photos", role: .destructive) {
                onProcessPhotos()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            let deleteCount = access.getPhotosToDelete().count
            Text("This will permanently delete \(deleteCount) photo\(deleteCount == 1 ? "" : "s") that you've tagged for deletion. This action cannot be undone.")
        }
        .alert("Processing Complete", isPresented: $showProcessAlert) {
            Button("OK", role: .cancel) {
                processResult = nil
            }
        } message: {
            if let result = processResult {
                if result.errors.isEmpty {
                    Text("Successfully deleted \(result.deleted) photo\(result.deleted == 1 ? "" : "s").")
                } else {
                    Text("Deleted \(result.deleted) photo\(result.deleted == 1 ? "" : "s"). \(result.errors.count) error\(result.errors.count == 1 ? "" : "s") occurred.")
                }
            }
        }
    }
    
    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 12) {  // Reduced spacing from 16
            ProgressBarView(access: access, isVertical: true)
                .frame(maxHeight: .infinity)
            ActionsDropdown(
                access: access,
                isSelecting: selectingBinding,
                selectedCount: selectedCount,
                showFilterView: $showFilterView,
                showClearConfirm: $showClearConfirm,
                showProcessConfirm: $showProcessConfirm,
                isProcessing: isProcessing
            )
        }
        .padding(12)  // Reduced padding from default
        .frame(width: 96)  // Match footer width of 96
        .background(.ultraThinMaterial)
        .overlay(Divider().opacity(0.4), alignment: .trailing)
    }
    
    private var horizontalLayout: some View {
        HStack(spacing: 10) {  // Reduced spacing from 12
            ProgressBarView(access: access, isVertical: false)
                .frame(maxWidth: .infinity)
            ActionsDropdown(
                access: access,
                isSelecting: selectingBinding,
                selectedCount: selectedCount,
                showFilterView: $showFilterView,
                showClearConfirm: $showClearConfirm,
                showProcessConfirm: $showProcessConfirm,
                isProcessing: isProcessing
            )
        }
        .padding(.horizontal, 12)  // Reduced from default padding
        .padding(.vertical, 6)  // Reduced from 8
        .frame(height: 92)  // Match footer height of 92
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }
}
