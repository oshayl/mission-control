// BackupManager.swift
// Daily JSON snapshot to ~/Documents/MissionControl/backups/.
// Keeps the last 7 snapshots, prunes older.

import Foundation

final class BackupManager {
    static let shared = BackupManager()

    private let fm = FileManager.default

    var backupDir: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
        return docs.appendingPathComponent("MissionControl/backups", isDirectory: true)
    }

    private var sourceFile: URL {
        let p = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? ""
        return URL(fileURLWithPath: p).appendingPathComponent("MissionControl/mission.json")
    }

    func runDailyBackup() {
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        guard fm.fileExists(atPath: sourceFile.path) else { return }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let name = "mission-\(df.string(from: Date())).json"
        let dest = backupDir.appendingPathComponent(name)
        if fm.fileExists(atPath: dest.path) { return }   // already backed up today
        do {
            try fm.copyItem(at: sourceFile, to: dest)
            pruneOldBackups(keep: 7)
        } catch {
            NSLog("BackupManager: failed to copy — \(error)")
        }
    }

    private func pruneOldBackups(keep n: Int) {
        guard let files = try? fm.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.creationDateKey]) else { return }
        let sorted = files
            .filter { $0.pathExtension == "json" }
            .sorted { (lhs, rhs) -> Bool in
                let l = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return l > r
            }
        for url in sorted.dropFirst(n) {
            try? fm.removeItem(at: url)
        }
    }
}
