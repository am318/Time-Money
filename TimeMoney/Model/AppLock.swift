import Foundation
import LocalAuthentication
import SwiftUI

/// Face ID / Touch ID gate.
///
/// This app holds take-home pay, what the bills come to, what is being saved and —
/// when Portfolio is linked — the shape of the whole plan. Any one of those is the
/// kind of thing you would rather not have on screen for whoever picks the phone up,
/// and the hourly rate on the home screen is the first thing anyone sees.
///
/// Deliberately the same shape as Portfolio's lock, down to the fallback: a device
/// with no biometrics *and* no passcode unlocks rather than trapping somebody out of
/// their own data.
@MainActor
@Observable
final class AppLock {
    private(set) var isUnlocked = false
    private(set) var lastError: String?

    /// Whether the device can do it at all, so the setting can be hidden rather than
    /// offered and then failing.
    static var isAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    static var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "your passcode"
        }
    }

    func lock() { isUnlocked = false }

    func unlock(reason: String = "Unlock Time / Money") async {
        let context = LAContext()
        context.localizedFallbackTitle = "Use passcode"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics and no passcode: locking would lock the owner out.
            isUnlocked = true
            return
        }

        do {
            isUnlocked = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            lastError = nil
        } catch {
            isUnlocked = false
            lastError = (error as? LAError)?.localizedDescription ?? error.localizedDescription
        }
    }
}

/// The screen shown while locked. Deliberately blank of any figure at all — a lock
/// that still shows your hourly rate on the way past is decoration.
struct LockedView: View {
    let lock: AppLock

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            Text("Time / Money is locked")
                .font(.title3.weight(.semibold))
            if let error = lock.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await lock.unlock() }
            } label: {
                Label("Unlock with \(AppLock.biometryName)", systemImage: "faceid")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
