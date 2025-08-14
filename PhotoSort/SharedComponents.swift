//
//  SharedComponents.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/11/25.
//

import SwiftUI
import Photos
import UIKit

// MARK: - Shared Enums

enum TaggingDecision {
    case keep, delete, unsure
}

// MARK: - Optimized Thumbnail Cell

struct ThumbnailCell<Content: View>: View {
    let asset: PHAsset
    let side: CGFloat
    let access: PhotoAccess
    let content: (UIImage) -> Content
    
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?
    @State private var hasAppeared = false
    
    var body: some View {
        ZStack {
            if let image = image {
                content(image)
            } else {
                Rectangle()
                    .fill(Color(white: 0.1))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                            .opacity(hasAppeared ? 1 : 0)
                            .tint(.white)
                    )
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .onAppear {
            hasAppeared = true
            loadImageIfNeeded()
        }
        .onDisappear {
            // Cancel pending requests to prevent hangs
            if let requestID = requestID {
                access.cancelImageRequest(requestID)
                self.requestID = nil
            }
        }
    }
    
    private func loadImageIfNeeded() {
        guard image == nil && requestID == nil else { return }
        
        // Load async without blocking
        Task { @MainActor in
            // Small delay to let scrolling settle
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            
            // Check again after delay
            guard image == nil else { return }
            
            access.requestThumbnail(for: asset, side: side) { img in
                self.image = img
                self.requestID = nil
            }
        }
    }
}

// MARK: - Flash Banner View

struct FlashBannerView: View {
    let flash: TaggingDecision?
    
    var body: some View {
        if let flash {
            VStack {
                HStack {
                    Spacer()
                    Text(flash == .keep ? "Kept" :
                         flash == .delete ? "Deleted" : "Marked Unsure")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background((flash == .keep ? Color.green :
                                     flash == .delete ? Color.red : Color.orange).opacity(0.95))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.top, 20)
                Spacer()
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            .zIndex(2)
        }
    }
}
