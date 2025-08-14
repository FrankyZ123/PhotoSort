//
//  TaggingToolbar.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/11/25.
//

import SwiftUI
import Photos

struct TaggingToolbar: View {
    @ObservedObject var access: PhotoAccess
    @Binding var selectedIndex: Int
    @Binding var showDetail: Bool
    let onTag: (TaggingDecision) -> Void
    var isVertical: Bool = false
    var isSelecting: Bool = false
    var selectedCount: Int = 0
    var onBulkTag: ((TaggingDecision) -> Void)? = nil
    var onCancelSelection: (() -> Void)? = nil  // Callback for clearing selection
    var onExitSelection: (() -> Void)? = nil  // Callback for exiting to grid
    
    @State private var showFilterView = false
    
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
    }
    
    private var verticalLayout: some View {
        ZStack {
            // Background that extends top to bottom
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea(.container, edges: .vertical)
            
            VStack(spacing: 32) {  // Increased spacing
                exitButton(size: 56)  // Exit button at top
                tagButton(.delete, color: .red, icon: "trash.fill", size: 56)
                tagButton(.unsure, color: .orange, icon: "questionmark", size: 64, shadow: true)  // Biggest
                tagButton(.keep, color: .green, icon: "checkmark", size: 56)
                filterButton(size: 56)  // Filter button at bottom
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
        }
        .frame(width: 96)  // Increased width
        .overlay(Divider().opacity(0.4), alignment: .leading)
    }
    
    private var horizontalLayout: some View {
        ZStack {
            // Background that extends edge to edge
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea(.container, edges: .horizontal)
            
            HStack(spacing: 28) {  // Increased spacing
                exitButton(size: 56)  // Exit button on left
                tagButton(.delete, color: .red, icon: "trash.fill", size: 56)
                tagButton(.unsure, color: .orange, icon: "questionmark", size: 64, shadow: true)  // Biggest
                tagButton(.keep, color: .green, icon: "checkmark", size: 56)
                filterButton(size: 56)  // Filter button on right
            }
            .padding(.vertical, 14)
        }
        .frame(height: 92)  // Increased height
        .overlay(Divider().opacity(0.4), alignment: .top)
    }
    
    @ViewBuilder
    private func tagButton(_ decision: TaggingDecision, color: Color, icon: String, size: CGFloat, shadow: Bool = false) -> some View {
        // Determine if button should be active - now including when any photos are selected
        let isActive = if selectedCount > 0 {
            true  // Active when ANY photos are selected (grid or detail view)
        } else if showDetail {
            true  // Always active in detail view
        } else {
            false  // Inactive only when in grid with nothing selected
        }
        
        let fillColor = isActive ? color : Color.gray.opacity(0.3)
        
        Button(action: {
            if selectedCount > 0 && !showDetail {
                // Bulk tagging in grid view
                onBulkTag?(decision) ?? ()
            } else if showDetail {
                // Single photo tagging in detail view
                onTag(decision)
            }
        }) {
            Circle()
                .fill(fillColor)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: size == 64 ? 30 : 26, weight: .bold))  // Adjusted icon sizes
                        .foregroundColor(isActive ? .white : .gray)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isActive)
        .shadow(radius: shadow && isActive ? 6 : 0)
        .opacity(isActive ? 1.0 : 0.6)
        .scaleEffect(isActive && shadow ? 1.05 : 1.0)  // Slight scale for the middle button
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .accessibilityLabel(decision == .delete ? "Delete" : decision == .unsure ? "Unsure" : "Keep")
    }
    
    @ViewBuilder
    private func exitButton(size: CGFloat) -> some View {
        // Active in selection mode OR when in detail view
        let isActive = isSelecting || selectedCount > 0 || showDetail
        
        Button(action: {
            if showDetail {
                // Close detail view (same as X button)
                showDetail = false
            } else if isActive {
                // Exit selection mode
                onExitSelection?()
            }
        }) {
            Circle()
                .fill(isActive ? Color.gray.opacity(0.8) : Color.gray.opacity(0.3))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(isActive ? .white : .gray)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isActive)
        .opacity(isActive ? 1.0 : 0.6)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .accessibilityLabel(showDetail ? "Close" : "Back to Grid")
    }
    
    @ViewBuilder
    private func filterButton(size: CGFloat) -> some View {
        Button(action: {
            showFilterView = true
        }) {
            Circle()
                .fill(access.isFilterActive ? Color.blue.opacity(0.9) : Color.gray.opacity(0.5))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                )
        }
        .buttonStyle(.plain)
        .shadow(radius: access.isFilterActive ? 3 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: access.isFilterActive)
        .accessibilityLabel("Filter Photos")
    }
    
    @ViewBuilder
    private func placeholderButton(size: CGFloat) -> some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .disabled(true)
    }
}
