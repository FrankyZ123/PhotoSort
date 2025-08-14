//
//  PhotoSortApp.swift
//  PhotoSort
//
//  Created by Zane Sand on 8/10/25.
//

import SwiftUI
import os
import UserNotifications

@main
struct PhotoSortApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var badgeManager = BadgeManager.shared
    
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
                .environmentObject(badgeManager)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Update badge when app goes to background
                    badgeManager.updateBadgeCount()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Clear badge when app becomes active
                    badgeManager.clearBadge()
                }
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

// App Delegate for handling notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Request notification permissions for badge updates
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { granted, error in
            if granted {
                print("Badge notification permission granted")
            } else if let error = error {
                print("Badge notification error: \(error)")
            }
        }
        return true
    }
}

// Badge Manager to handle badge count updates
@MainActor
class BadgeManager: ObservableObject {
    static let shared = BadgeManager()
    @Published var unsortedCount: Int = 0
    
    private init() {}
    
    func updateBadgeCount() {
        // Update the app badge with unsorted count
        UNUserNotificationCenter.current().setBadgeCount(unsortedCount) { error in
            if let error = error {
                print("Error setting badge count: \(error)")
            }
        }
    }
    
    func clearBadge() {
        // Clear badge when app is active
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("Error clearing badge: \(error)")
            }
        }
    }
    
    func setUnsortedCount(_ count: Int) {
        unsortedCount = count
    }
}
