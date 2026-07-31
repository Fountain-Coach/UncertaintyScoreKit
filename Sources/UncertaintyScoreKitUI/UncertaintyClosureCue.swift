import Foundation

/// One wording authority for the visible and accessible rendering of `UncertaintyNote.resolvedBy`.
///
/// `resolvedBy` names a possible next operation. It does not say the note has already been resolved.
public enum UncertaintyClosureCue {
    public static func text(for operation: String?) -> String {
        guard let operation = operation?.trimmingCharacters(in: .whitespacesAndNewlines),
              !operation.isEmpty else {
            return ""
        }
        return "Could be closed by: \(operation)"
    }
}
