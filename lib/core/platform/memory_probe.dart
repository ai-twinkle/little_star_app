import 'dart:io';

/// Reads the current process's resident memory footprint.
///
/// Kept as its own small interface — mirroring [ThermalProbe]/[BatteryProbe]
/// — so benchmark recorder logic can be unit-tested without depending on the
/// real OS-reported value. Backed by `dart:io`'s [ProcessInfo], so (unlike
/// thermal/battery) no platform channel is needed.
abstract class MemoryProbe {
  /// Current resident set size in bytes.
  int currentRssBytes();
}

/// Production implementation — delegates to `dart:io`'s [ProcessInfo].
///
/// [ProcessInfo.currentRss] is whole-process RSS, matching how this cycle's
/// on-device memory measurements were taken manually (task-A02/A03: Xcode
/// Instruments / `dumpsys meminfo`, both whole-process, not scoped to a
/// single allocation) — the benchmark recorder samples this periodically
/// during a run and reports the peak observed sample.
class DartIoMemoryProbe implements MemoryProbe {
  @override
  int currentRssBytes() => ProcessInfo.currentRss;
}
