import AppKit
import CoreGraphics

public final class SpaceManager {
    public static let shared = SpaceManager()
    private init() {}

    public struct SpaceInfo {
        public let id: Int
        public let displayId: UInt32
        public let isCurrentSpace: Bool
    }

    /// Get list of spaces via CGS private API (best-effort, may fail on newer macOS)
    public func getSpaces() -> [SpaceInfo] {
        guard let displays = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as? [[String: Any]] else {
            return []
        }
        var spaces: [SpaceInfo] = []
        for display in displays {
            let displayId = display["Display Identifier"] as? String ?? ""
            let displayUInt: UInt32 = displayId.contains("Main") ? CGMainDisplayID() : 0
            if let spacesList = display["Spaces"] as? [[String: Any]] {
                let currentSpaceId = (display["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int ?? 0
                for space in spacesList {
                    if let spaceId = space["ManagedSpaceID"] as? Int {
                        spaces.append(SpaceInfo(id: spaceId, displayId: displayUInt, isCurrentSpace: spaceId == currentSpaceId))
                    }
                }
            }
        }
        return spaces
    }

    public func getCurrentSpaceId() -> Int? {
        getSpaces().first(where: \.isCurrentSpace)?.id
    }
}

// CGS Private API declarations
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> Int

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ connection: Int) -> CFArray?
