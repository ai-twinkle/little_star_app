// Implements DeviceTelemetryHostApi (Pigeon-generated protocol).
//
// Backs the C-line benchmark harness's thermal-state reading on iOS.

import Foundation

final class DeviceTelemetryBridge: DeviceTelemetryHostApi {
    func getThermalState() throws -> ThermalStatus {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        @unknown default:
            return .unknown
        }
    }
}
