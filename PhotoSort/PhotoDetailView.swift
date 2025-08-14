//
//  PhotoDetailView.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/11/25.
//

import SwiftUI
import Photos

struct PhotoDetailView: View {
    let assets: [PHAsset]
    @Binding var index: Int
    let access: PhotoAccess
    @Binding var showDetail: Bool
    
    var body: some View {
        // Defer everything to a background-loaded view
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Use the current asset directly - no array processing
            if assets.indices.contains(index) {
                SinglePhotoView(
                    asset: assets[index],
                    assets: assets,
                    index: $index,
                    access: access,
                    showDetail: $showDetail
                )
            }
        }
    }
}

// Minimal single photo viewer with fast filmstrip
struct SinglePhotoView: View {
    let asset: PHAsset
    let assets: [PHAsset]
    @Binding var index: Int
    let access: PhotoAccess
    @Binding var showDetail: Bool
    
    @State private var currentImage: UIImage? = nil
    @State private var showControls = false
    @State private var showFilmstrip = false
    @State private var nextImage: UIImage? = nil
    @State private var prevImage: UIImage? = nil
    @State private var isFilmstripScrolling = false
    @State private var fullImageTimer: Timer?
    @State private var loadedThumbnails: [String: UIImage] = [:]
    
    var body: some View {
        ZStack {
            // Photo with swipe support
            photoSwipeView
            
            // Minimal controls overlay
            if showControls {
                controlsOverlay
            }
        }
        .ignoresSafeArea()
        .safeAreaInset(edge: .bottom) {
            // Filmstrip appears after initial load
            if showFilmstrip {
                FastFilmstrip(
                    assets: assets,
                    currentIndex: $index,
                    access: access,
                    isScrolling: $isFilmstripScrolling,
                    loadedThumbnails: $loadedThumbnails
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            loadImage()
            // Show controls and filmstrip after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls = true
                    showFilmstrip = true
                }
            }
        }
        .onChange(of: index) { _ in
            if !isFilmstripScrolling {
                loadImage()
            } else {
                // When scrolling through filmstrip, only load thumbnail
                loadThumbnailForCurrent()
            }
        }
        .onChange(of: isFilmstripScrolling) { scrolling in
            if !scrolling {
                // Stopped scrolling - load full image after delay
                fullImageTimer?.invalidate()
                fullImageTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    loadImage()
                }
            }
        }
    }
    
    @ViewBuilder
    private var photoSwipeView: some View {
        if isFilmstripScrolling {
            // During filmstrip scrolling, show simple image view for speed
            ZStack {
                Color.black
                
                if let cachedThumb = loadedThumbnails[assets[index].localIdentifier] {
                    Image(uiImage: cachedThumb)
                        .resizable()
                        .scaledToFit()
                } else if let currentImage = currentImage {
                    Image(uiImage: currentImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .ignoresSafeArea()
        } else {
            // Use a simpler gesture-based approach instead of TabView
            ZStack {
                Color.black
                
                // Current photo
                if let image = currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        handleSwipeGesture(value)
                    }
            )
        }
    }
    
    private func handleSwipeGesture(_ value: DragGesture.Value) {
        let horizontalAmount = value.translation.width
        let verticalAmount = value.translation.height
        
        // Prioritize horizontal swipes
        if abs(horizontalAmount) > abs(verticalAmount) {
            if horizontalAmount < -50 {
                // Swipe left - next photo
                if index < assets.count - 1 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        index += 1
                        loadImage()
                    }
                }
            } else if horizontalAmount > 50 {
                // Swipe right - previous photo
                if index > 0 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        index -= 1
                        loadImage()
                    }
                }
            }
        } else if verticalAmount > 100 {
            // Swipe down to dismiss
            showDetail = false
        }
    }
    
    private var visibleIndices: [Int] {
        // Only load current and immediate neighbors
        var indices: [Int] = []
        if index > 0 { indices.append(index - 1) }
        indices.append(index)
        if index < assets.count - 1 { indices.append(index + 1) }
        return indices
    }
    
    @ViewBuilder
    private func photoPage(at idx: Int) -> some View {
        let isCurrent = idx == index
        
        ZStack {
            Color.black
            
            if isCurrent && currentImage != nil {
                Image(uiImage: currentImage!)
                    .resizable()
                    .scaledToFit()
            } else if idx == index - 1 && prevImage != nil {
                Image(uiImage: prevImage!)
                    .resizable()
                    .scaledToFit()
            } else if idx == index + 1 && nextImage != nil {
                Image(uiImage: nextImage!)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .tint(.white)
                    .onAppear {
                        if idx == index - 1 {
                            loadAdjacentImage(at: idx, isPrev: true)
                        } else if idx == index + 1 {
                            loadAdjacentImage(at: idx, isPrev: false)
                        }
                    }
            }
        }
    }
    
    @ViewBuilder
    private var controlsOverlay: some View {
        // Only show tag badge now - X button removed
        if let tag = access.tag(for: assets[index]) {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    TagBadge(tag: tag)
                        .scaleEffect(1.5)
                        .padding(24)
                }
            }
        }
    }
    
    private func loadThumbnailForCurrent() {
        guard assets.indices.contains(index) else { return }
        let targetAsset = assets[index]
        let assetId = targetAsset.localIdentifier
        
        // Use cached thumbnail if available
        if let cached = loadedThumbnails[assetId] {
            currentImage = cached
        } else {
            // Load new thumbnail
            access.requestThumbnail(for: targetAsset, side: UIScreen.main.bounds.width) { image in
                if let image = image {
                    self.currentImage = image
                    self.loadedThumbnails[assetId] = image
                }
            }
        }
    }
    
    private func loadImage() {
        guard assets.indices.contains(index) else { return }
        let targetAsset = assets[index]
        
        // Clear adjacent images when index changes
        prevImage = nil
        nextImage = nil
        
        // Quick thumbnail
        access.requestThumbnail(for: targetAsset, side: UIScreen.main.bounds.width) { image in
            if let image = image {
                self.currentImage = image
                self.loadedThumbnails[targetAsset.localIdentifier] = image
                
                // Then full image
                access.requestFullImage(for: targetAsset) { fullImage in
                    if let fullImage = fullImage {
                        self.currentImage = fullImage
                    }
                }
                
                // Preload adjacent images after current is loaded
                if index > 0 {
                    loadAdjacentImage(at: index - 1, isPrev: true)
                }
                if index < assets.count - 1 {
                    loadAdjacentImage(at: index + 1, isPrev: false)
                }
            }
        }
    }
    
    private func loadAdjacentImage(at idx: Int, isPrev: Bool) {
        guard assets.indices.contains(idx) else { return }
        
        access.requestThumbnail(for: assets[idx], side: UIScreen.main.bounds.width) { image in
            if let image = image {
                if isPrev {
                    self.prevImage = image
                } else {
                    self.nextImage = image
                }
                self.loadedThumbnails[assets[idx].localIdentifier] = image
            }
        }
    }
}

// Ultra-smooth fast scrolling filmstrip
struct FastFilmstrip: View {
    let assets: [PHAsset]
    @Binding var currentIndex: Int
    let access: PhotoAccess
    @Binding var isScrolling: Bool
    @Binding var loadedThumbnails: [String: UIImage]
    
    @State private var thumbnails: [String: UIImage] = [:]
    
    private let itemSize: CGFloat = 60
    private let spacing: CGFloat = 6
    
    var body: some View {
        ZStack {
            // Background
            Color.clear
                .background(.ultraThinMaterial)
            
            // Pure UIKit scroll view for maximum performance
            LightweightFilmstrip(
                assets: assets,
                currentIndex: $currentIndex,
                isScrolling: $isScrolling,
                thumbnails: thumbnails,
                loadedThumbnails: loadedThumbnails,
                access: access,
                onThumbnailLoad: { id, image in
                    // Defer state update to avoid modification during view update
                    DispatchQueue.main.async {
                        self.thumbnails[id] = image
                        self.loadedThumbnails[id] = image
                    }
                }
            )
            
            // Center selection box
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: itemSize, height: itemSize)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                )
                .allowsHitTesting(false)
                .shadow(color: .black.opacity(0.5), radius: 4)
        }
        .frame(height: 78)
        .overlay(Divider().opacity(0.4), alignment: .top)
    }
}

// Lightweight pure UIKit implementation
struct LightweightFilmstrip: UIViewRepresentable {
    let assets: [PHAsset]
    @Binding var currentIndex: Int
    @Binding var isScrolling: Bool
    let thumbnails: [String: UIImage]
    let loadedThumbnails: [String: UIImage]
    let access: PhotoAccess
    let onThumbnailLoad: (String, UIImage) -> Void
    
    private let itemSize: CGFloat = 60
    private let spacing: CGFloat = 6
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = .normal
        scrollView.backgroundColor = .clear
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        
        setupContent(scrollView: scrollView, context: context)
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Update thumbnails for visible items only
        updateVisibleThumbnails(scrollView: scrollView)
        
        // Update tag indicators
        updateTagIndicators(scrollView: scrollView)
        
        // Update position if needed
        if !context.coordinator.isUserInteracting {
            let currentOffset = scrollView.contentOffset.x
            let targetOffset = calculateOffset(for: currentIndex)
            if abs(currentOffset - targetOffset) > itemSize {
                scrollView.setContentOffset(CGPoint(x: targetOffset, y: 0), animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    private func setupContent(scrollView: UIScrollView, context: Context) {
        // Create a simple container
        let container = UIView()
        container.backgroundColor = .clear
        
        // Calculate dimensions
        let itemFullWidth = itemSize + spacing
        let screenWidth = UIScreen.main.bounds.width
        let leadingSpace = (screenWidth - itemSize) / 2
        let totalWidth = CGFloat(assets.count) * itemFullWidth - spacing + leadingSpace * 2
        
        container.frame = CGRect(x: 0, y: 0, width: totalWidth, height: 78)
        scrollView.contentSize = container.frame.size
        scrollView.addSubview(container)
        
        // Store container reference
        context.coordinator.container = container
        context.coordinator.itemViews = []
        
        // Create placeholder views for all items (but don't load images yet)
        for (index, asset) in assets.enumerated() {
            let x = leadingSpace + CGFloat(index) * itemFullWidth
            let frame = CGRect(x: x, y: 9, width: itemSize, height: itemSize)
            
            let itemView = FilmstripItemView(frame: frame)
            itemView.index = index
            itemView.asset = asset
            itemView.coordinator = context.coordinator
            
            // Add tag indicator if needed
            if let tag = access.tag(for: asset) {
                itemView.setTagIndicator(tag)
            }
            
            container.addSubview(itemView)
            context.coordinator.itemViews.append(itemView)
        }
        
        // Initial scroll position and immediate thumbnail loading
        DispatchQueue.main.async {
            let targetX = self.calculateOffset(for: self.currentIndex)
            scrollView.setContentOffset(CGPoint(x: targetX, y: 0), animated: false)
            // Load visible thumbnails immediately
            self.loadVisibleThumbnails(in: scrollView)
            
            // Also preload a few more thumbnails nearby
            self.preloadNearbyThumbnails(in: scrollView)
        }
    }
    
    private func preloadNearbyThumbnails(in scrollView: UIScrollView) {
        guard let container = scrollView.subviews.first else { return }
        
        // Preload thumbnails within 5 items of current position
        let preloadRange = max(0, currentIndex - 5)...min(assets.count - 1, currentIndex + 5)
        
        for subview in container.subviews {
            if let itemView = subview as? FilmstripItemView,
               preloadRange.contains(itemView.index),
               itemView.imageView.image == nil,
               let asset = itemView.asset {
                
                let assetId = asset.localIdentifier
                if let cached = loadedThumbnails[assetId] ?? thumbnails[assetId] {
                    itemView.imageView.image = cached
                } else {
                    loadThumbnailAsync(for: asset, into: itemView)
                }
            }
        }
    }
    
    private func updateVisibleThumbnails(scrollView: UIScrollView) {
        guard let container = scrollView.subviews.first else { return }
        
        let visibleRect = CGRect(
            x: scrollView.contentOffset.x,
            y: 0,
            width: scrollView.bounds.width,
            height: scrollView.bounds.height
        )
        
        for subview in container.subviews {
            if let itemView = subview as? FilmstripItemView {
                let isVisible = visibleRect.intersects(itemView.frame)
                if isVisible && itemView.imageView.image == nil {
                    if let asset = itemView.asset {
                        let assetId = asset.localIdentifier
                        if let cached = loadedThumbnails[assetId] ?? thumbnails[assetId] {
                            itemView.imageView.image = cached
                        } else {
                            loadThumbnailAsync(for: asset, into: itemView)
                        }
                    }
                }
            }
        }
    }
    
    private func updateTagIndicators(scrollView: UIScrollView) {
        guard let container = scrollView.subviews.first else { return }
        
        for subview in container.subviews {
            if let itemView = subview as? FilmstripItemView,
               let asset = itemView.asset {
                if let tag = access.tag(for: asset) {
                    itemView.setTagIndicator(tag)
                } else {
                    itemView.removeTagIndicator()
                }
            }
        }
    }
    
    private func loadVisibleThumbnails(in scrollView: UIScrollView) {
        updateVisibleThumbnails(scrollView: scrollView)
    }
    
    private func loadThumbnailAsync(for asset: PHAsset, into itemView: FilmstripItemView) {
        access.requestThumbnail(for: asset, side: itemSize * UIScreen.main.scale) { image in
            if let image = image {
                DispatchQueue.main.async {
                    itemView.imageView.image = image
                    self.onThumbnailLoad(asset.localIdentifier, image)
                }
            }
        }
    }
    
    private func calculateOffset(for index: Int) -> CGFloat {
        let itemFullWidth = itemSize + spacing
        let screenWidth = UIScreen.main.bounds.width
        let leadingSpace = (screenWidth - itemSize) / 2
        return leadingSpace + CGFloat(index) * itemFullWidth - (screenWidth - itemSize) / 2
    }
    
    // Custom item view with tag support
    class FilmstripItemView: UIView {
        let imageView = UIImageView()
        var tagIndicator: UIView?
        var index: Int = 0
        var asset: PHAsset?
        weak var coordinator: Coordinator?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupView()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupView() {
            backgroundColor = UIColor.systemGray6
            layer.cornerRadius = 8
            clipsToBounds = true
            
            imageView.frame = bounds
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            addSubview(imageView)
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            addGestureRecognizer(tap)
        }
        
        func setTagIndicator(_ tag: PhotoTag) {
            // Remove existing indicator if any
            tagIndicator?.removeFromSuperview()
            
            // Create new indicator
            let indicator = UIView(frame: CGRect(x: 4, y: 4, width: 18, height: 18))
            indicator.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            indicator.layer.cornerRadius = 9
            
            let iconView = UIImageView(frame: indicator.bounds)
            iconView.contentMode = .center
            iconView.tintColor = tagColor(for: tag)
            
            let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
            iconView.image = UIImage(systemName: tagIcon(for: tag), withConfiguration: config)
            
            indicator.addSubview(iconView)
            addSubview(indicator)
            tagIndicator = indicator
        }
        
        func removeTagIndicator() {
            tagIndicator?.removeFromSuperview()
            tagIndicator = nil
        }
        
        private func tagIcon(for tag: PhotoTag) -> String {
            switch tag {
            case .keep: return "checkmark.circle.fill"
            case .delete: return "trash.circle.fill"
            case .unsure: return "questionmark.circle.fill"
            }
        }
        
        private func tagColor(for tag: PhotoTag) -> UIColor {
            switch tag {
            case .keep: return .systemGreen
            case .delete: return .systemRed
            case .unsure: return .systemOrange
            }
        }
        
        @objc private func handleTap() {
            coordinator?.handleItemTap(index: index)
        }
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: LightweightFilmstrip
        var isUserInteracting = false
        var container: UIView?
        var itemViews: [FilmstripItemView] = []
        var lastIndex = -1
        let feedback = UISelectionFeedbackGenerator()
        
        init(parent: LightweightFilmstrip) {
            self.parent = parent
            super.init()
            feedback.prepare()
        }
        
        func handleItemTap(index: Int) {
            feedback.selectionChanged()
            // Defer state updates
            DispatchQueue.main.async {
                self.parent.currentIndex = index
                self.parent.isScrolling = false
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserInteracting = true
            // Defer state update
            DispatchQueue.main.async {
                self.parent.isScrolling = true
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Calculate centered index
            let itemFullWidth = parent.itemSize + parent.spacing
            let screenWidth = UIScreen.main.bounds.width
            let centerX = scrollView.contentOffset.x + screenWidth / 2
            let leadingSpace = (screenWidth - parent.itemSize) / 2
            let adjustedX = centerX - leadingSpace
            let index = Int(round(adjustedX / itemFullWidth))
            let clampedIndex = max(0, min(parent.assets.count - 1, index))
            
            if clampedIndex != lastIndex {
                feedback.selectionChanged()
                lastIndex = clampedIndex
                
                // Defer state update to avoid modification during view update
                DispatchQueue.main.async {
                    self.parent.currentIndex = clampedIndex
                }
                
                // Update visible thumbnails while scrolling
                parent.updateVisibleThumbnails(scrollView: scrollView)
            }
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                snapToNearest(scrollView)
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            snapToNearest(scrollView)
        }
        
        private func snapToNearest(_ scrollView: UIScrollView) {
            isUserInteracting = false
            let targetX = parent.calculateOffset(for: parent.currentIndex)
            
            UIView.animate(withDuration: 0.25, delay: 0,
                          usingSpringWithDamping: 0.9,
                          initialSpringVelocity: 0,
                          options: .allowUserInteraction) {
                scrollView.setContentOffset(CGPoint(x: targetX, y: 0), animated: false)
            } completion: { _ in
                // Defer state update
                DispatchQueue.main.async {
                    self.parent.isScrolling = false
                }
            }
        }
    }
}
