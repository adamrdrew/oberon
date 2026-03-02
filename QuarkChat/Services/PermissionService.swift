import Foundation
import EventKit
import Contacts
import UserNotifications
#if canImport(MusicKit)
import MusicKit
#endif

actor PermissionService {
    static let shared = PermissionService()

    private let eventStore = EKEventStore()

    // MARK: - Reminders / Calendar

    func requestRemindersAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToReminders()
        } catch {
            return false
        }
    }

    func requestCalendarAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    var eventStoreInstance: EKEventStore { eventStore }

    // MARK: - Contacts

    func requestContactsAccess() async -> Bool {
        let store = CNContactStore()
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            return false
        }
    }

    // MARK: - Notifications (for Timers)

    func requestNotificationAccess() async -> Bool {
        do {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                return true
            case .notDetermined:
                return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            default:
                return false
            }
        } catch {
            return false
        }
    }

    // MARK: - MusicKit

    #if canImport(MusicKit)
    func requestMusicAccess() async -> Bool {
        let status = await MusicAuthorization.request()
        return status == .authorized
    }
    #endif
}
