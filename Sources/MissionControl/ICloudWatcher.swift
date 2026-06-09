// ICloudWatcher.swift
// Watches the iCloud ubiquity file for external changes (other Mac edited it)
// and re-loads the data store.

import Foundation
import Combine

final class ICloudWatcher {
    static let shared = ICloudWatcher()
    private var query: NSMetadataQuery?
    private var observer: NSObjectProtocol?
    private var debounceTimer: Timer?

    private init() {}

    func start(onChange: @escaping () -> Void) {
        guard query == nil else { return }
        guard let ubiquity = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            NSLog("ICloudWatcher: no ubiquity container — sync via local file only")
            return
        }
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        q.valueListAttributes = [
            NSMetadataItemURLKey,
            NSMetadataItemFSNameKey,
            NSMetadataItemFSContentChangeDateKey
        ]
        q.predicate = NSPredicate(format: "%K == %@",
                                  NSMetadataItemFSNameKey,
                                  "mission.json")
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: q,
            queue: .main
        ) { [weak self] _ in
            self?.debounce(onChange: onChange)
        }
        // Silently absorb initial gathering updates — only act on changes after the
        // initial state is loaded, otherwise we trigger spurious reloads at launch.
        q.gatheringThreshold = NSMetadataQueryGatheringThresholdOne
        q.start()
        self.query = q
        NSLog("ICloudWatcher: watching \(ubiquity.path)/Documents/mission.json")
    }

    private func debounce(onChange: @escaping () -> Void) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
            DispatchQueue.main.async { onChange() }
        }
    }

    func stop() {
        query?.stop()
        if let obs = observer { NotificationCenter.default.removeObserver(obs) }
        query = nil
        observer = nil
    }
}
