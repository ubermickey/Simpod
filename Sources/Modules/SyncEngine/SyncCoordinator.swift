import Foundation

/// Two-method seam between DataStore and SyncEngine.
/// Lets DataStore notify the sync layer of local mutations without
/// importing CloudKit. Tests inject a recording double.
protocol SyncCoordinator: AnyObject, Sendable {
    func markDirty(id: UUID)
    func markDeleted(id: UUID)
}
