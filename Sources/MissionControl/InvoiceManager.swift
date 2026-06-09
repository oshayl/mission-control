// InvoiceManager.swift
// Minimal invoice draft generation. Saves a markdown file to ~/Documents/MissionControl/invoices/.
// Future: wire to a real invoicing provider (Stripe / QuickBooks).

import Foundation
import AppKit

struct InvoiceDraft: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var number: String       // INV-YYMM-001
    var clientID: UUID
    var clientName: String
    var company: String?
    var email: String?
    var items: [LineItem] = []
    var notes: String = ""
    var dueDate: Date
    var createdAt: Date = Date()
    var status: String = "draft"  // draft / sent / paid / overdue

    struct LineItem: Codable, Identifiable, Equatable, Hashable {
        var id: UUID = UUID()
        var description: String
        var quantity: Double = 1
        var rate: Double = 0

        var total: Double { quantity * rate }
    }

    var subtotal: Double { items.map { $0.total }.reduce(0, +) }
    var total: Double { subtotal }
}

final class InvoiceManager {
    static let shared = InvoiceManager()

    private let counterKey = "mc.invoice.counter"

    var invoicesDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
        return docs.appendingPathComponent("MissionControl/invoices", isDirectory: true)
    }

    func nextInvoiceNumber() -> String {
        let now = Date()
        let f = DateFormatter()
        f.dateFormat = "yyMM"
        let prefix = "INV-\(f.string(from: now))"
        let key = "\(counterKey).\(prefix)"
        let n = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(n, forKey: key)
        return String(format: "%@-%03d", prefix, n)
    }

    @discardableResult
    func createDraft(for client: Client, description: String, amount: Double) -> InvoiceDraft {
        let draft = InvoiceDraft(
            number: nextInvoiceNumber(),
            clientID: client.id,
            clientName: client.displayName,
            company: client.company,
            email: client.email,
            items: [InvoiceDraft.LineItem(description: description, quantity: 1, rate: amount)],
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        )
        save(draft: draft)
        return draft
    }

    func save(draft: InvoiceDraft) {
        try? FileManager.default.createDirectory(at: invoicesDir, withIntermediateDirectories: true)
        let url = invoicesDir.appendingPathComponent("\(draft.number).json")
        let data = (try? JSONEncoder.iso.encode(draft)) ?? Data()
        try? data.write(to: url)
    }

    func loadAll() -> [InvoiceDraft] {
        try? FileManager.default.createDirectory(at: invoicesDir, withIntermediateDirectories: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: invoicesDir, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder.iso.decode(InvoiceDraft.self, from: data)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func renderMarkdown(_ d: InvoiceDraft) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        let lines = """
        # Invoice \(d.number)

        **To:** \(d.company ?? d.clientName)
        **Date:** \(f.string(from: d.createdAt))
        **Due:** \(f.string(from: d.dueDate))

        | Description | Qty | Rate | Total |
        |---|---|---|---|
        \(d.items.map { "| \($0.description) | \(String(format: "%.0f", $0.quantity)) | $\(String(format: "%.2f", $0.rate)) | $\(String(format: "%.2f", $0.total)) |" }.joined(separator: "\n"))

        **Total: $\(String(format: "%.2f", d.total))**

        \(d.notes.isEmpty ? "" : "\(d.notes)\n")

        Pay via Venmo · Cash App · Zelle · Bitcoin — see profile.
        """
        return lines
    }
}
