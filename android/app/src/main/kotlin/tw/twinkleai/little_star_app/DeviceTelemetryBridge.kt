// Implements DeviceTelemetryHostApi (Pigeon-generated interface).
//
// Backs the C-line benchmark harness's thermal-state reading on Android.

package tw.twinkleai.little_star_app

import android.content.Context
import android.os.Build
import android.os.PowerManager

class DeviceTelemetryBridge(private val context: Context) : DeviceTelemetryHostApi {
    override fun getThermalState(): ThermalStatus {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            // PowerManager.getCurrentThermalStatus() requires API 29+.
            return ThermalStatus.UNKNOWN
        }
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return ThermalStatus.UNKNOWN
        return when (powerManager.currentThermalStatus) {
            PowerManager.THERMAL_STATUS_NONE -> ThermalStatus.NOMINAL
            PowerManager.THERMAL_STATUS_LIGHT,
            PowerManager.THERMAL_STATUS_MODERATE -> ThermalStatus.FAIR
            PowerManager.THERMAL_STATUS_SEVERE -> ThermalStatus.SERIOUS
            PowerManager.THERMAL_STATUS_CRITICAL,
            PowerManager.THERMAL_STATUS_EMERGENCY,
            PowerManager.THERMAL_STATUS_SHUTDOWN -> ThermalStatus.CRITICAL
            else -> ThermalStatus.UNKNOWN
        }
    }
}
