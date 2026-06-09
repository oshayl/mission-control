// WebhookServer.swift
// Tiny HTTP server on localhost:8787 for incoming leads from track.noira.us CRM.
// Endpoints:
//   POST /lead   { name, company?, phone?, email?, imessage?, github?, notes?, source? }
//   GET  /health
//   GET  /clients (returns count for sanity)

import Foundation
import Network

final class WebhookServer {
    static let shared = WebhookServer()
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 8787
    private(set) var running = false

    weak var store: DataStore?

    func start(store: DataStore) {
        self.store = store
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        do {
            let l = try NWListener(using: params, on: port)
            l.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
            l.start(queue: .global(qos: .background))
            self.listener = l
            self.running = true
            NSLog("WebhookServer: listening on http://127.0.0.1:\(port)")
        } catch {
            NSLog("WebhookServer: failed to start — \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        running = false
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .global(qos: .background))
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { data, _, _, _ in
            let req = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let response = self.route(req)
            conn.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                conn.cancel()
            })
        }
    }

    private func route(_ raw: String) -> String {
        // Very small parser: first line = "METHOD /path HTTP/1.1"
        let lines = raw.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
        guard let firstLine = lines.first else { return response(400, "bad request") }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return response(400, "bad request") }
        let method = String(parts[0])
        let path = String(parts[1])

        // Body = everything after first blank line
        let body: String
        if let idx = lines.firstIndex(of: "") {
            body = lines[(idx + 1)...].joined(separator: "\r\n")
        } else {
            body = ""
        }

        switch (method, path) {
        case ("GET", "/health"):
            return response(200, "ok")
        case ("GET", "/clients"):
            let count = DispatchQueue.main.sync { store?.data.clients.count ?? 0 }
            return response(200, "{\"count\":\(count)}")
        case ("POST", "/lead"):
            return handleLead(body: body)
        default:
            return response(404, "not found")
        }
    }

    private func handleLead(body: String) -> String {
        guard let data = body.data(using: .utf8) else { return response(400, "bad body") }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return response(400, "invalid json")
        }
        guard let name = json["name"] as? String, !name.isEmpty else {
            return response(400, "missing name")
        }
        let statusRaw = json["status"] as? String ?? "lead"
        let status = ClientStatus(rawValue: statusRaw) ?? .lead
        var c = Client(name: name, status: status)
        c.company = json["company"] as? String
        c.phone = json["phone"] as? String
        c.email = json["email"] as? String
        c.imessageHandle = json["imessage"] as? String
        c.githubLogin = json["github"] as? String
        c.notes = json["notes"] as? String ?? ""
        if let tags = json["tags"] as? [String] { c.tags = tags }
        if let src = json["source"] as? String, !src.isEmpty {
            c.notes = (c.notes.isEmpty ? "" : c.notes + "\n") + "Source: \(src)"
        }
        let newID = c.id
        let nameEcho = name
        DispatchQueue.main.async {
            self.store?.upsert(c)
            self.store?.triggerPulse()
        }
        return response(200, "{\"id\":\"\(newID.uuidString)\",\"name\":\"\(nameEcho)\"}")
    }

    private func response(_ code: Int, _ body: String) -> String {
        let reason: String
        switch code {
        case 200: reason = "OK"
        case 400: reason = "Bad Request"
        case 404: reason = "Not Found"
        default: reason = "OK"
        }
        return """
        HTTP/1.1 \(code) \(reason)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r
        \(body)
        """
    }
}
