import Foundation
import Contacts
import FoundationModels

struct ComposeMessageProcessor: Sendable {

    func process(query: String) async -> DomainResult {
        let hasAccess = await PermissionService.shared.requestContactsAccess()

        do {
            let session = LanguageModelSession(
                instructions: "Extract the recipient name, subject (for email), message body, and channel (email or sms) from the user's request."
            )

            let response = try await session.respond(
                to: query,
                generating: ComposeExtraction.self
            )

            let extraction = response.content
            let recipient = extraction.recipient.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = extraction.body.trimmingCharacters(in: .whitespacesAndNewlines)
            let channel = extraction.channel.lowercased()

            guard !recipient.isEmpty else { return .empty }

            // Try to look up contact for phone/email
            var contactAddress: String?
            if hasAccess {
                let store = CNContactStore()
                let keys: [CNKeyDescriptor] = [
                    CNContactGivenNameKey as CNKeyDescriptor,
                    CNContactFamilyNameKey as CNKeyDescriptor,
                    CNContactPhoneNumbersKey as CNKeyDescriptor,
                    CNContactEmailAddressesKey as CNKeyDescriptor,
                ]
                let predicate = CNContact.predicateForContacts(matchingName: recipient)
                if let contact = try? store.unifiedContacts(matching: predicate, keysToFetch: keys).first {
                    if channel == "email" {
                        contactAddress = contact.emailAddresses.first?.value as String?
                    } else {
                        contactAddress = contact.phoneNumbers.first?.value.stringValue
                    }
                }
            }

            let action: RichAction
            if channel == "email" {
                let email = contactAddress ?? ""
                let subject = extraction.subject.trimmingCharacters(in: .whitespacesAndNewlines)
                var urlComponents = "mailto:\(email)"
                var params: [String] = []
                if !subject.isEmpty { params.append("subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)") }
                if !body.isEmpty { params.append("body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body)") }
                if !params.isEmpty { urlComponents += "?" + params.joined(separator: "&") }

                action = RichAction(
                    type: .sendEmail,
                    label: "Send Email",
                    subtitle: "To: \(recipient)",
                    urlString: urlComponents
                )
            } else {
                let phone = contactAddress?.filter { $0.isNumber || $0 == "+" } ?? ""
                var smsURL = "sms:\(phone)"
                if !body.isEmpty {
                    smsURL += "&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body)"
                }

                action = RichAction(
                    type: .messageContact,
                    label: "Send Message",
                    subtitle: "To: \(recipient)",
                    urlString: smsURL
                )
            }

            let channelLabel = channel == "email" ? "email" : "message"
            return DomainResult(
                enrichmentText: "Ready to send \(channelLabel) to \(recipient).\(body.isEmpty ? "" : " Message: \(body)")",
                citations: [],
                actions: [action],
                richContent: [],
                suggestedReplies: []
            )
        } catch {
            return .empty
        }
    }
}
