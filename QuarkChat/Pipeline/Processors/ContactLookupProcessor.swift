import Foundation
import Contacts
import FoundationModels

struct ContactLookupProcessor: Sendable {

    func process(query: String) async -> DomainResult {
        let hasAccess = await PermissionService.shared.requestContactsAccess()
        guard hasAccess else {
            return DomainResult(
                enrichmentText: "I need access to Contacts to look up contact information. Please grant permission in Settings > Privacy > Contacts.",
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: []
            )
        }

        do {
            let session = LanguageModelSession(
                instructions: "Extract the person's name and what info the user wants from the query."
            )

            let response = try await session.respond(
                to: query,
                generating: ContactExtraction.self
            )

            let extraction = response.content
            let name = extraction.personName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return .empty }

            // Search contacts
            let store = CNContactStore()
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
            ]

            let predicate = CNContact.predicateForContacts(matchingName: name)
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)

            guard let contact = contacts.first else {
                return DomainResult(
                    enrichmentText: "No contact found for '\(name)'.",
                    citations: [],
                    actions: [],
                    richContent: [],
                    suggestedReplies: []
                )
            }

            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let phone = contact.phoneNumbers.first?.value.stringValue
            let email = (contact.emailAddresses.first?.value as String?)

            let contactData = ContactData(
                name: fullName,
                phoneNumber: phone,
                email: email
            )

            var actions: [RichAction] = []
            if let phone = phone {
                let digits = phone.filter { $0.isNumber || $0 == "+" }
                actions.append(RichAction(
                    type: .callContact,
                    label: "Call",
                    subtitle: fullName,
                    urlString: "tel:\(digits)"
                ))
                actions.append(RichAction(
                    type: .messageContact,
                    label: "Message",
                    subtitle: fullName,
                    urlString: "sms:\(digits)"
                ))
            }
            if let email = email {
                actions.append(RichAction(
                    type: .sendEmail,
                    label: "Email",
                    subtitle: fullName,
                    urlString: "mailto:\(email)"
                ))
            }

            var enrichmentParts: [String] = ["Contact: \(fullName)"]
            if let phone = phone { enrichmentParts.append("Phone: \(phone)") }
            if let email = email { enrichmentParts.append("Email: \(email)") }

            return DomainResult(
                enrichmentText: enrichmentParts.joined(separator: "\n"),
                citations: [],
                actions: actions,
                richContent: [.contact(contactData)],
                suggestedReplies: SuggestedReply.forContact()
            )
        } catch {
            return .empty
        }
    }
}
