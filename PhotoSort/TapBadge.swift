//
//  TagBadge.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/11/25.
//

import SwiftUI

struct TagBadge: View {
    let tag: PhotoTag
    @State private var isAnimating = false
    
    var body: some View {
        let symbol: String
        let color: Color
        switch tag {
        case .keep:
            symbol = "checkmark.circle.fill"
            color = .green
        case .delete:
            symbol = "trash.circle.fill"
            color = .red
        case .unsure:
            symbol = "questionmark.circle.fill"
            color = .orange
        }
        
        return Image(systemName: symbol)
            .foregroundStyle(.white, color)
            .font(.system(size: 20, weight: .semibold))
            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isAnimating = false
                }
            }
    }
}
