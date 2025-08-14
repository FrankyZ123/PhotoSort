//
//  FilmstripItemView.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/11/25.
//

import SwiftUI
import Photos
import UIKit

struct FilmstripItemView: View {
    let asset: PHAsset
    let index: Int
    let isSelected: Bool
    let itemSide: CGFloat
    let thumbnail: UIImage?
    let tag: PhotoTag?
    let onAppear: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: itemSide, height: itemSide)
                    .clipped()
            } else {
                Rectangle().fill(Color.white.opacity(0.08))
                    .frame(width: itemSide, height: itemSide)
                    .overlay(ProgressView().scaleEffect(0.7).tint(.white))
                    .onAppear { onAppear() }
            }
            
            if let tag = tag {
                Group {
                    switch tag {
                    case .keep:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .delete:
                        Image(systemName: "trash.circle.fill")
                            .foregroundStyle(.red)
                    case .unsure:
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .background(Color.black.opacity(0.7))
                .clipShape(Circle())
                .padding(6)
            }
        }
        .cornerRadius(8)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
