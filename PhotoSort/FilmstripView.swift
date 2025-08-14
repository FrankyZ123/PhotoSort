//
//  FilmstripView.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/11/25.
//

import SwiftUI
import Photos
import Foundation

struct FilmstripView: View {
    let assets: [PHAsset]
    @Binding var currentIndex: Int
    let access: PhotoAccess
    let height: CGFloat
    @Binding var isScrolling: Bool
    
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var loadedThumbnails: Set<String> = []
    @State private var localIndex: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isAutoScrolling = false
    @State private var scrollTimer: Timer?
    @State private var isUserScrolling = false
    
    private var itemSide: CGFloat { height - 18 }
    private let spacing: CGFloat = 6
    private var itemFullWidth: CGFloat { itemSide + spacing }
    
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea(.container, edges: .horizontal)
                
                // Scrollable filmstrip
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing) {
                            // Leading spacer
                            Color.clear
                                .frame(width: (geometry.size.width - itemSide) / 2)
                            
                            ForEach(assets.indices, id: \.self) { i in
                                FilmstripItemView(
                                    asset: assets[i],
                                    index: i,
                                    isSelected: i == currentIndex,
                                    itemSide: itemSide,
                                    thumbnail: thumbnails[assets[i].localIdentifier],
                                    tag: access.tag(for: assets[i]),
                                    onAppear: { loadThumbnail(for: assets[i]) },
                                    onTap: {
                                        hapticFeedback.impactOccurred()
                                        localIndex = i
                                        currentIndex = i
                                        isScrolling = false
                                        // Smooth scroll to center when tapped
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            proxy.scrollTo(i, anchor: .center)
                                        }
                                    }
                                )
                                .id(i)
                            }
                            
                            // Trailing spacer
                            Color.clear
                                .frame(width: (geometry.size.width - itemSide) / 2)
                        }
                        .padding(.vertical, 9)
                        .background(
                            GeometryReader { scrollGeo in
                                Color.clear
                                    .onChange(of: scrollGeo.frame(in: .named("scroll")).minX) { newValue in
                                        // Only process scroll changes when user is scrolling, not auto-scrolling
                                        if !isAutoScrolling {
                                            scrollOffset = newValue
                                            isUserScrolling = true
                                            
                                            // Cancel any existing timer
                                            scrollTimer?.invalidate()
                                            
                                            // Calculate which photo is in the center selection box
                                            let centerX = geometry.size.width / 2
                                            let leadingSpace = (geometry.size.width - itemSide) / 2
                                            let adjustedOffset = -scrollOffset + centerX - leadingSpace - (itemSide / 2)
                                            let rawIndex = adjustedOffset / itemFullWidth
                                            let centerIndex = max(0, min(assets.count - 1, Int(round(rawIndex))))
                                            
                                            // Update the index if it changed
                                            if centerIndex != localIndex {
                                                hapticFeedback.impactOccurred()
                                                localIndex = centerIndex
                                                currentIndex = centerIndex
                                                isScrolling = true  // Tell PhotoDetailView we're scrolling
                                            }
                                            
                                            // Set timer to auto-center after scrolling stops
                                            scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                                                if isUserScrolling {
                                                    isUserScrolling = false
                                                    isAutoScrolling = true
                                                    // Snap to center the current photo
                                                    withAnimation(.easeInOut(duration: 0.3)) {
                                                        proxy.scrollTo(currentIndex, anchor: .center)
                                                    }
                                                    // Reset flags after animation
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                                        isAutoScrolling = false
                                                        isScrolling = false
                                                    }
                                                }
                                            }
                                        }
                                    }
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onAppear {
                        hapticFeedback.prepare()
                        localIndex = currentIndex
                        // Initial centering
                        DispatchQueue.main.async {
                            proxy.scrollTo(currentIndex, anchor: .center)
                        }
                    }
                    .onChange(of: currentIndex) { newIndex in
                        // Auto-scroll when index changes from outside (swiping in detail view)
                        if newIndex != localIndex && assets.indices.contains(newIndex) {
                            localIndex = newIndex
                            isAutoScrolling = true
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                            // Reset flag after animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                isAutoScrolling = false
                            }
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { _ in
                                // Cancel timer while actively dragging
                                scrollTimer?.invalidate()
                                isUserScrolling = true
                            }
                            .onEnded { _ in
                                // The timer in the scroll onChange will handle the centering
                                // Just need to ensure we're tracking that user stopped
                                isUserScrolling = true
                            }
                    )
                }
                
                // Center selection box
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: itemSide, height: itemSide)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(0.3), lineWidth: 1)
                        )
                        .allowsHitTesting(false)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                    Spacer()
                }
                .padding(.vertical, 9)
            }
        }
        .frame(height: height)
        .overlay(Divider().opacity(0.4), alignment: .top)
    }
    
    private func loadThumbnail(for asset: PHAsset) {
        let id = asset.localIdentifier
        guard !loadedThumbnails.contains(id) else { return }
        loadedThumbnails.insert(id)
        access.requestThumbnail(for: asset, side: itemSide) { img in
            if let img = img { thumbnails[id] = img }
        }
    }
}
