// CalendarReader.swift
// Reads macOS Calendar (EventKit) to find the next meeting per client
// (matched by attendee email or by keyword in title/notes).

import Foundation
import EventKit

struct CalendarEventLite: Hashable {
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let url: String?
    let notes: String?
    let attendees: [String]
    let calendar: String
}

final class CalendarReader {
    static let shared = CalendarReader()
    private let store = EKEventStore()
    private var authorized = false

    private init() {}

    func requestAccess() async -> Bool {
        if authorized { return true }
        if #available(macOS 14.0, *) {
            do {
                let granted = try await store.requestFullAccessToEvents()
                authorized = granted
                return granted
            } catch {
                return false
            }
        } else {
            do {
                let granted = try await store.requestAccess(to: .event)
                authorized = granted
                return granted
            } catch {
                return false
            }
        }
    }

    /// Find the next event that matches the client (by email/handle/company/name in title, notes, or attendees).
    func nextEvent(for client: Client) async -> CalendarEventLite? {
        guard await requestAccess() else { return nil }
        let now = Date()
        let twoMonthsOut = Calendar.current.date(byAdding: .day, value: 60, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: now, end: twoMonthsOut, calendars: nil)
        let events = store.events(matching: predicate)
        let needles = matchNeedles(for: client)
        return events
            .filter { ev in matches(event: ev, needles: needles) }
            .sorted { $0.startDate < $1.startDate }
            .first
            .map { ev in
                let attendeeEmails: [String] = (ev.attendees ?? []).compactMap { p in
                    (p.value(forKey: "emailAddress") as? String)
                }
                return CalendarEventLite(
                    title: ev.title ?? "(no title)",
                    start: ev.startDate,
                    end: ev.endDate,
                    location: ev.location,
                    url: ev.url?.absoluteString,
                    notes: ev.notes,
                    attendees: attendeeEmails,
                    calendar: ev.calendar?.title ?? "Calendar"
                )
            }
    }

    private func matchNeedles(for client: Client) -> [String] {
        var n: [String] = []
        n.append(contentsOf: client.name.split(separator: " ").map(String.init))
        if let co = client.company { n.append(co); n.append(contentsOf: co.split(separator: " ").map(String.init)) }
        if let em = client.email { n.append(em) }
        if let im = client.imessageHandle, im.contains("@") { n.append(im) }
        return n.filter { $0.count >= 3 }
    }

    private func matches(event: EKEvent, needles: [String]) -> Bool {
        let title = (event.title ?? "").lowercased()
        let notes = (event.notes ?? "").lowercased()
        let location = (event.location ?? "").lowercased()
        // EKParticipant has no emailAddress on macOS; match on the email property if exposed.
        let attendeeEmails: [String] = (event.attendees ?? []).compactMap { p in
            // KVC fallback to be safe across iOS/macOS SDKs.
            (p.value(forKey: "emailAddress") as? String)
        }
        let attendees = attendeeEmails.joined(separator: " ").lowercased()
        let haystack = "\(title) \(notes) \(location) \(attendees)"
        for n in needles {
            let nl = n.lowercased()
            if haystack.contains(nl) { return true }
        }
        return false
    }
}
