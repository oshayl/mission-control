// DeepLinkHandler.swift
// Handles missioncontrol:// URLs to open specific clients or perform actions.

import Foundation
import AppKit

final class DeepLinkHandler {
    static let shared = DeepLinkHandler()
    weak var store: DataStore?
    weak var appDelegate: AppDelegate?

    func handle(_ url: URL) {
        guard url.scheme == "missioncontrol" else { return }
        Task { @MainActor in
            self.handleOnMain(url)
        }
    }

    @MainActor
    private func handleOnMain(_ url: URL) {
        let host = url.host ?? ""
        let path = url.pathComponents.filter { $0 != "/" }
        switch host {
        case "client":
            if let idStr = path.first, let id = UUID(uuidString: idStr) {
                store?.selectedClientID = id
                appDelegate?.showPopover()
            }
        case "add":
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let q = comps?.queryItems ?? []
            var c = Client(name: "New")
            for item in q {
                switch item.name {
                case "name": c.name = item.value ?? "New"
                case "company": c.company = item.value
                case "phone": c.phone = item.value
                case "email": c.email = item.value
                case "imessage": c.imessageHandle = item.value
                case "github": c.githubLogin = item.value
                case "status":
                    if let s = item.value, let st = ClientStatus(rawValue: s) { c.status = st }
                default: break
                }
            }
            store?.upsert(c)
            store?.selectedClientID = c.id
            appDelegate?.showPopover()
        case "show":
            appDelegate?.showPopover()
        case "settings":
            store?.showSettings = true
            appDelegate?.showPopover()
        default:
            break
        }
    }
}
