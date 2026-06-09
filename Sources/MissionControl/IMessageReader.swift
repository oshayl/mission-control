// iMessageReader.swift
// Reads ~/Library/Messages/chat.db to surface last iMessage conversation
// with each client. Powers auto-updating lastContact.

import Foundation
import SQLite3

struct IMessageContact: Hashable {
    let handle: String          // phone or email
    let lastMessageAt: Date
    let lastMessageText: String
    let lastFromMe: Bool
    let unread: Bool
}

final class IMessageReader {
    static let shared = IMessageReader()

    private static let SQLITE_TRANSIENT = unsafeBitCast(
        OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self
    )

    private var chatDBPath: String {
        let home = NSHomeDirectory()
        return "\(home)/Library/Messages/chat.db"
    }

    /// Returns the most recent message exchanged with `handle`.
    /// `handle` may be a phone (+1417…) or email.
    func lastMessage(with handle: String) -> IMessageContact? {
        let normalized = normalizeHandle(handle)
        guard FileManager.default.fileExists(atPath: chatDBPath) else { return nil }
        // chat.db can be locked by Messages.app while it's writing.
        // Use a read-only mode and tolerate SQLITE_BUSY.
        var db: OpaquePointer?
        defer { if db != nil { sqlite3_close(db) } }
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(chatDBPath, &db, flags, nil) == SQLITE_OK else { return nil }
        // 5 second busy timeout to wait for Messages.app to release.
        sqlite3_busy_timeout(db, 5000)
        return lastMessageAlt(db: db, handle: normalized)
    }

    private func lastMessageAlt(db: OpaquePointer?, handle: String) -> IMessageContact? {
        // Step 1: find chat_ids that contain this handle
        let lookupSQL = """
        SELECT chj.chat_id
        FROM chat_handle_join chj
        JOIN handle h ON h.ROWID = chj.handle_id
        WHERE h.id = ?;
        """
        var stmt: OpaquePointer?
        defer { if stmt != nil { sqlite3_finalize(stmt) } }
        guard sqlite3_prepare_v2(db, lookupSQL, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, handle, -1, Self.SQLITE_TRANSIENT)

        var chatIDs: [Int64] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            chatIDs.append(sqlite3_column_int64(stmt, 0))
        }
        if chatIDs.isEmpty { return nil }

        // Step 2: most recent message in any of those chats
        let placeholders = chatIDs.map { _ in "?" }.joined(separator: ",")
        let msgSQL = """
        SELECT text, date, is_from_me, is_read
        FROM message
        WHERE text IS NOT NULL AND text != ''
          AND cache_roomnames IN (\(placeholders))
        ORDER BY date DESC
        LIMIT 1;
        """
        var msgStmt: OpaquePointer?
        defer { if msgStmt != nil { sqlite3_finalize(msgStmt) } }
        guard sqlite3_prepare_v2(db, msgSQL, -1, &msgStmt, nil) == SQLITE_OK else { return nil }
        for (i, id) in chatIDs.enumerated() {
            sqlite3_bind_int64(msgStmt, Int32(i + 1), id)
        }
        guard sqlite3_step(msgStmt) == SQLITE_ROW else { return nil }
        let text = String(cString: sqlite3_column_text(msgStmt, 0))
        let appleDate = sqlite3_column_int64(msgStmt, 1)
        let fromMe = sqlite3_column_int(msgStmt, 2) == 1
        let isRead = sqlite3_column_int(msgStmt, 3) == 1
        // Apple Cocoa time: seconds since 2001-01-01 00:00:00 UTC
        let unix = appleDate + 978307200
        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        return IMessageContact(
            handle: handle,
            lastMessageAt: date,
            lastMessageText: text,
            lastFromMe: fromMe,
            unread: !isRead
        )
    }

    private func normalizeHandle(_ h: String) -> String {
        var s = h.trimmingCharacters(in: .whitespaces)
        // Apple stores phones without '+', with digits only
        if !s.contains("@") {
            s = s.replacingOccurrences(of: "+", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
        }
        return s
    }
}
