//  CloudKitBootstrapper.swift
//  Oberon
//
//  DEBUG-only: pushes the SwiftData schema to CloudKit's Dev environment
//  using NSPersistentCloudKitContainer.initializeCloudKitSchema().
//  Versioned via UserDefaults so it only runs once per schema change.

import Foundation
import os

#if DEBUG
import CloudKit
import CoreData
import SwiftData

struct CloudKitBootstrapper {

    static func bootstrapIfNeeded(
        modelTypes: [any PersistentModel.Type],
        containerID: String,
        userDefaultsKey: String,
        currentVersion: Int,
        logger: Logger
    ) {
        let already = UserDefaults.standard.integer(forKey: userDefaultsKey)
        guard already < currentVersion else {
            logger.debug("CK bootstrap skipped (v\(already)).")
            return
        }

        do {
            try autoreleasepool {
                let schema = Schema(modelTypes)
                guard let mom = NSManagedObjectModel.makeManagedObjectModel(for: schema) else {
                    throw NSError(
                        domain: "Oberon.CloudKitInit",
                        code: 1,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Failed to synthesize NSManagedObjectModel"
                        ]
                    )
                }

                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("CKBootstrap-\(UUID().uuidString).sqlite")

                let desc = NSPersistentStoreDescription(url: tempURL)
                desc.shouldAddStoreAsynchronously = false
                desc.cloudKitContainerOptions = .init(containerIdentifier: containerID)

                let temp = NSPersistentCloudKitContainer(
                    name: "OberonCKBootstrap",
                    managedObjectModel: mom
                )
                temp.persistentStoreDescriptions = [desc]

                var loadErr: Error?
                temp.loadPersistentStores { _, err in loadErr = err }
                if let loadErr { throw loadErr }

                try temp.initializeCloudKitSchema()

                if let store = temp.persistentStoreCoordinator.persistentStores.first {
                    try temp.persistentStoreCoordinator.remove(store)
                }
            }

            UserDefaults.standard.set(currentVersion, forKey: userDefaultsKey)
            logger.debug("CK Dev schema bootstrap completed (v\(currentVersion)).")
        } catch {
            if shouldIgnoreError(error) {
                logger.info(
                    "CK bootstrap skipped due to expected condition: \(String(describing: error))"
                )
            } else {
                logger.warning("CK bootstrap failed: \(String(describing: error))")
            }
        }
    }

    private static func shouldIgnoreError(_ error: Error) -> Bool {
        if let ck = error as? CKError {
            switch ck.code {
            case .networkUnavailable, .networkFailure, .serviceUnavailable,
                .notAuthenticated, .requestRateLimited, .internalError:
                return true
            default: break
            }
        }
        return (error as NSError).domain == NSCocoaErrorDomain
    }
}
#endif
