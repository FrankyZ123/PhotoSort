//
//  GridCellView.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/11/25.
//

import SwiftUI
import Photos

struct GridCellView: View {
    let asset: PHAsset
    let index: Int
    let side: CGFloat
    let access: PhotoAccess
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Photo thumbnail with rounded corners
            ThumbnailCell(asset: asset, side: side, access: access) { image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Gentle selection overlay
            if isSelecting && isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.blue, lineWidth: 2)
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
            }
            
            // Tag badge with subtle shadow for depth - now on the left
            if let tag = access.tag(for: asset) {
                Group {
                    switch tag {
                    case .keep:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, .green)
                    case .delete:
                        Image(systemName: "trash.circle.fill")
                            .foregroundStyle(.white, .red)
                    case .unsure:
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(.white, .orange)
                    }
                }
                .font(.system(size: 18, weight: .semibold))
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                .padding(6)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Selection checkbox in top right when in selection mode
            if isSelecting {
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.blue : Color.black.opacity(0.5))
                                .frame(width: 24, height: 24)
                            
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 1.5)
                                .frame(width: 24, height: 24)
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                    }
                    Spacer()
                }
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            // Quick press animation
            withAnimation(.spring(response: 0.1, dampingFraction: 0.8)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                onTap()
            }
        }
    }
}
