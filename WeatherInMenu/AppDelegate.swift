//
//  AppDelegate.swift
//  StatusBarTextApp
//
//  Created by 민식 on 4/12/25.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        startBackgroundTimer()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // 앱 종료 시 처리
    }

    // 상태 바에 텍스트 표시
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "내이름은 김민식"
            button.action = #selector(statusBarClicked)
        }
    }
    //상태창 클릭시
    @objc func statusBarClicked() {
        // 클릭 시 동작 (선택 사항)
        print("Status bar item clicked")
    }

    func startBackgroundTimer() {
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.updateStatusText("🕒 \(self.currentTime())")
        }
    }

    func updateStatusText(_ text: String) {
        DispatchQueue.main.async {
            self.statusItem?.button?.title = text
        }
    }

    func currentTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}
