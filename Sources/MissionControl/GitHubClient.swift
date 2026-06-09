// GitHubClient.swift
// Lightweight GitHub API client. No auth (public repos / events) for now.
// Fetches recent activity (push events) for a given user.

import Foundation

struct GitHubActivity: Hashable {
    let repo: String              // "owner/name"
    let kind: String              // "push", "pr", "issue", "star", "release", "fork"
    let title: String             // commit msg / PR title / etc.
    let url: String?
    let timestamp: Date
}

final class GitHubClient {
    static let shared = GitHubClient()

    private let session: URLSession
    private var cache: [String: (at: Date, items: [GitHubActivity])] = [:]
    private let cacheTTL: TimeInterval = 120  // 2 min

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetch recent public activity for a GitHub login.
    func recentActivity(for login: String) async -> [GitHubActivity] {
        let login = login.trimmingCharacters(in: .whitespaces)
        guard !login.isEmpty else { return [] }
        if let hit = cache[login], Date().timeIntervalSince(hit.at) < cacheTTL {
            return hit.items
        }
        guard let url = URL(string: "https://api.github.com/users/\(login)/events/public?per_page=30") else { return [] }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Mission-Control/0.3", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            let events = try JSONDecoder().decode([GitHubEvent].self, from: data)
            let items = events.compactMap { e -> GitHubActivity? in
                let ts = Self.parseGitHubDate(e.created_at) ?? Date()
                switch e.type {
                case "PushEvent":
                    let branch = e.payload?.ref?.replacingOccurrences(of: "refs/heads/", with: "") ?? "main"
                    let firstCommit = e.payload?.commits?.first
                    return GitHubActivity(
                        repo: e.repo.name, kind: "push",
                        title: firstCommit?.message ?? "pushed to \(branch)",
                        url: firstCommit?.url ?? e.repo.url, timestamp: ts
                    )
                case "PullRequestEvent":
                    let action = e.payload?.action ?? "updated"
                    let title = e.payload?.pull_request?.title ?? "PR"
                    return GitHubActivity(
                        repo: e.repo.name, kind: "pr",
                        title: "\(action): \(title)",
                        url: e.payload?.pull_request?.html_url, timestamp: ts
                    )
                case "IssuesEvent":
                    let action = e.payload?.action ?? "updated"
                    let title = e.payload?.issue?.title ?? "issue"
                    return GitHubActivity(
                        repo: e.repo.name, kind: "issue",
                        title: "\(action): \(title)",
                        url: e.payload?.issue?.html_url, timestamp: ts
                    )
                case "CreateEvent":
                    return GitHubActivity(
                        repo: e.repo.name, kind: "create",
                        title: "created \(e.payload?.ref_type ?? "ref") \(e.payload?.ref ?? "")",
                        url: nil, timestamp: ts
                    )
                case "ReleaseEvent":
                    return GitHubActivity(
                        repo: e.repo.name, kind: "release",
                        title: "released \(e.payload?.release?.tag_name ?? "")",
                        url: e.payload?.release?.html_url, timestamp: ts
                    )
                case "WatchEvent":
                    return GitHubActivity(
                        repo: e.repo.name, kind: "star",
                        title: "starred",
                        url: nil, timestamp: ts
                    )
                case "ForkEvent":
                    return GitHubActivity(
                        repo: e.repo.name, kind: "fork",
                        title: "forked",
                        url: e.payload?.forkee?.html_url, timestamp: ts
                    )
                default:
                    return nil
                }
            }
            cache[login] = (Date(), items)
            return items
        } catch {
            return []
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoFallback: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static func parseGitHubDate(_ s: String) -> Date? {
        if let d = isoFormatter.date(from: s) { return d }
        return isoFallback.date(from: s)
    }
}

// MARK: - Decodable response types

private struct GitHubEvent: Decodable {
    let type: String
    let created_at: String
    let repo: GitHubRepoLite
    let payload: GitHubPayload?
}
private struct GitHubRepoLite: Decodable {
    let name: String
    let url: String
}
private struct GitHubPayload: Decodable {
    let ref: String?
    let ref_type: String?
    let action: String?
    let commits: [GitHubCommit]?
    let pull_request: GitHubPR?
    let issue: GitHubIssue?
    let release: GitHubRelease?
    let forkee: GitHubForkee?
}
private struct GitHubCommit: Decodable {
    let message: String
    let url: String
}
private struct GitHubPR: Decodable {
    let title: String
    let html_url: String
}
private struct GitHubIssue: Decodable {
    let title: String
    let html_url: String
}
private struct GitHubRelease: Decodable {
    let tag_name: String
    let html_url: String
}
private struct GitHubForkee: Decodable {
    let html_url: String
}
