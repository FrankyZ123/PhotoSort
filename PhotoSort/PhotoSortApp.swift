//
//  PhotoSortApp.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/10/25.
//

import SwiftUI
import os

@main
struct PhotoSortApp: App {
    init() {
        // Configure image cache for better performance
        configureImageCache()
        
        // Monitor main thread hangs in debug
        #if DEBUG
        monitorMainThreadHangs()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            MainContainerView()
        }
    }
    
    private func configureImageCache() {
        // Increase image cache limits for better performance
        let cache = URLCache.shared
        cache.memoryCapacity = 100 * 1024 * 1024 // 100 MB
        cache.diskCapacity = 500 * 1024 * 1024   // 500 MB
    }
    
    #if DEBUG
    private func monitorMainThreadHangs() {
        if #available(iOS 16.0, *) {
            Task { @MainActor in
                let logger = Logger(subsystem: "PhotoSort", category: "Performance")
                
                // Monitor app lifecycle for performance
                for await notification in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                    logger.info("App became active")
                    OSSignposter().beginInterval("AppActive", id: .exclusive)
                }
            }
            
            // Add main thread checker
            DispatchQueue.global(qos: .userInteractive).async {
                while true {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    DispatchQueue.main.sync {
                        // Check if main thread is responsive
                        _ = UIApplication.shared.windows.first
                    }
                    
                    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                    if elapsed > 0.25 {
                        print("⚠️ Main thread hang detected: \(String(format: "%.2f", elapsed))s")
                    }
                    
                    Thread.sleep(forTimeInterval: 1.0) // Check every second
                }
            }
        }
    }
    #endif
}
