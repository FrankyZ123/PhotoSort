//
//  FilterView.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/11/25.
//

import SwiftUI
import Photos

struct FilterView: View {
    @ObservedObject var access: PhotoAccess
    @Binding var isPresented: Bool
    
    @State private var tempFilters: Set<PhotoTag>
    @State private var tempShowUntagged: Bool
    @State private var tempSelectedCollection: PHAssetCollection?
    @State private var albumsExpanded = false
    @State private var tagsExpanded = false
    
    init(access: PhotoAccess, isPresented: Binding<Bool>) {
        self.access = access
        self._isPresented = isPresented
        self._tempFilters = State(initialValue: access.activeFilters)
        self._tempShowUntagged = State(initialValue: access.showUntagged)
        self._tempSelectedCollection = State(initialValue: access.selectedCollection)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Albums Section
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    albumsExpanded.toggle()
                                }
                            } label: {
                                HStack {
                                    Label("Albums", systemImage: "folder")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(tempSelectedCollection?.localizedTitle ?? "All Photos")
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Image(systemName: albumsExpanded ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                            }
                            
                            if albumsExpanded {
                                VStack(spacing: 0) {
                                    Divider()
                                    
                                    // All Photos option
                                    Button {
                                        tempSelectedCollection = nil
                                    } label: {
                                        HStack {
                                            Image(systemName: "photo.on.rectangle.angled")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.blue)
                                                .frame(width: 30)
                                            Text("All Photos")
                                                .foregroundColor(.primary)
                                            Spacer()
                                            if tempSelectedCollection == nil {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                        }
                                        .padding()
                                        .background(tempSelectedCollection == nil ? Color.blue.opacity(0.08) : Color.clear)
                                    }
                                    
                                    // User albums
                                    ForEach(collections, id: \.localIdentifier) { collection in
                                        Divider()
                                        Button {
                                            tempSelectedCollection = collection
                                        } label: {
                                            HStack {
                                                Image(systemName: "folder")
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(.blue)
                                                    .frame(width: 30)
                                                Text(collection.localizedTitle ?? "Untitled")
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                Spacer()
                                                if tempSelectedCollection?.localIdentifier == collection.localIdentifier {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.blue)
                                                        .font(.system(size: 14, weight: .semibold))
                                                }
                                            }
                                            .padding()
                                            .background(tempSelectedCollection?.localIdentifier == collection.localIdentifier ? Color.blue.opacity(0.08) : Color.clear)
                                        }
                                    }
                                }
                                .background(Color(UIColor.tertiarySystemGroupedBackground))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Tags Section
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    tagsExpanded.toggle()
                                }
                            } label: {
                                HStack {
                                    Label("Tags", systemImage: "tag")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(getActiveTagsDescription())
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Image(systemName: tagsExpanded ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                            }
                            
                            if tagsExpanded {
                                VStack(spacing: 0) {
                                    Divider()
                                    
                                    // Keep toggle
                                    TagToggleRow(
                                        title: "Keep",
                                        icon: "checkmark.circle.fill",
                                        color: .green,
                                        isOn: Binding(
                                            get: { tempFilters.contains(.keep) },
                                            set: { isOn in
                                                if isOn {
                                                    tempFilters.insert(.keep)
                                                } else {
                                                    tempFilters.remove(.keep)
                                                }
                                            }
                                        )
                                    )
                                    
                                    Divider()
                                    
                                    // Delete toggle
                                    TagToggleRow(
                                        title: "Delete",
                                        icon: "trash.circle.fill",
                                        color: .red,
                                        isOn: Binding(
                                            get: { tempFilters.contains(.delete) },
                                            set: { isOn in
                                                if isOn {
                                                    tempFilters.insert(.delete)
                                                } else {
                                                    tempFilters.remove(.delete)
                                                }
                                            }
                                        )
                                    )
                                    
                                    Divider()
                                    
                                    // Unsure toggle
                                    TagToggleRow(
                                        title: "Unsure",
                                        icon: "questionmark.circle.fill",
                                        color: .orange,
                                        isOn: Binding(
                                            get: { tempFilters.contains(.unsure) },
                                            set: { isOn in
                                                if isOn {
                                                    tempFilters.insert(.unsure)
                                                } else {
                                                    tempFilters.remove(.unsure)
                                                }
                                            }
                                        )
                                    )
                                    
                                    Divider()
                                    
                                    // Untagged toggle
                                    TagToggleRow(
                                        title: "Untagged",
                                        icon: "circle",
                                        color: .gray,
                                        isOn: $tempShowUntagged
                                    )
                                }
                                .background(Color(UIColor.tertiarySystemGroupedBackground))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                
                // Filter info
                VStack(spacing: 8) {
                    let totalCount = access.assets.count
                    let filteredCount = access.assets.filter { asset in
                        if let tag = access.tag(for: asset) {
                            return tempFilters.contains(tag)
                        } else {
                            return tempShowUntagged
                        }
                    }.count
                    
                    Text("Showing \(filteredCount) of \(totalCount) photos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if filteredCount == 0 {
                        Text("No photos match the current filter")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        tempFilters = Set(PhotoTag.allCases)
                        tempShowUntagged = true
                        tempSelectedCollection = nil
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Apply album selection
                        access.selectedCollection = tempSelectedCollection
                        // Apply filters
                        access.setFilter(tempFilters, showUntagged: tempShowUntagged)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Refresh collections when view appears
            access.refreshCollections()
        }
    }
    
    private var collections: [PHAssetCollection] {
        access.collections
    }
    
    private func getActiveTagsDescription() -> String {
        var activeTags: [String] = []
        
        if tempFilters.contains(.keep) { activeTags.append("Keep") }
        if tempFilters.contains(.delete) { activeTags.append("Delete") }
        if tempFilters.contains(.unsure) { activeTags.append("Unsure") }
        if tempShowUntagged { activeTags.append("Untagged") }
        
        if activeTags.isEmpty {
            return "None"
        } else if activeTags.count == 4 {
            return "All"
        } else if activeTags.count > 2 {
            return "\(activeTags.count) selected"
        } else {
            return activeTags.joined(separator: ", ")
        }
    }
}

// MARK: - Tag Toggle Row

struct TagToggleRow: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .frame(width: 30)
                Text(title)
                    .foregroundColor(.primary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding()
        .background(isOn ? color.opacity(0.08) : Color.clear)
    }
}
