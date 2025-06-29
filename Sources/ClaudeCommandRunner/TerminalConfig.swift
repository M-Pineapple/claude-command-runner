import Foundation
import AppKit

/// Terminal configuration and detection
public struct TerminalConfig {
    public enum TerminalType: String, CaseIterable {
        case warp = "Warp"
        case warpPreview = "WarpPreview"
        case iterm2 = "iTerm"
        case terminal = "Terminal"
        case alacritty = "Alacritty"
    }
    
    /// Detect which terminals are installed
    public static func detectInstalledTerminals() -> [TerminalType] {
        var installed: [TerminalType] = []
        let workspace = NSWorkspace.shared
        
        for terminal in TerminalType.allCases {
            let bundleId = getBundleIdentifier(for: terminal)
            if workspace.urlForApplication(withBundleIdentifier: bundleId) != nil {
                installed.append(terminal)
            }
        }
        
        return installed
    }
    
    /// Get the preferred terminal from config or auto-detect
    public static func getPreferredTerminal() -> TerminalType {
        // TODO: Read from config file first
        
        // Auto-detect in order of preference
        let preferences: [TerminalType] = [.warp, .warpPreview, .iterm2, .terminal]
        let installed = detectInstalledTerminals()
        
        for preference in preferences {
            if installed.contains(preference) {
                return preference
            }
        }
        
        // Fallback to Terminal.app
        return .terminal
    }
    
    /// Get bundle identifier for terminal type
    public static func getBundleIdentifier(for terminal: TerminalType) -> String {
        switch terminal {
        case .warp:
            return "dev.warp.Warp"
        case .warpPreview:
            return "dev.warp.Warp-Preview"
        case .iterm2:
            return "com.googlecode.iterm2"
        case .terminal:
            return "com.apple.Terminal"
        case .alacritty:
            return "org.alacritty"
        }
    }
    
    /// Get database path for Warp terminals
    public static func getWarpDatabasePath(for terminal: TerminalType) -> String? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        
        switch terminal {
        case .warp:
            return "\(homeDir)/Library/Application Support/dev.warp.Warp/warp.sqlite"
        case .warpPreview:
            return "\(homeDir)/Library/Application Support/dev.warp.Warp-Preview/warp.sqlite"
        default:
            return nil
        }
    }
    
    /// Check if terminal supports database integration
    public static func supportsDatabaseIntegration(_ terminal: TerminalType) -> Bool {
        switch terminal {
        case .warp, .warpPreview:
            return true
        default:
            return false
        }
    }
}
