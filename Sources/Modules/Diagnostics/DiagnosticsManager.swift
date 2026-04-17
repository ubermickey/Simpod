import MetricKit
import os

private let logger = Logger(subsystem: "com.simpod", category: "Diagnostics")

final class DiagnosticsManager: NSObject, MXMetricManagerSubscriber {
    func start() {
        MXMetricManager.shared.add(self)
        logger.info("MetricKit subscriber registered")
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            if let _ = payload.applicationLaunchMetrics {
                logger.info("MetricKit: launch histogram available")
            }
            if let _ = payload.applicationResponsivenessMetrics {
                logger.info("MetricKit: hang histogram available")
            }
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            logger.warning("MetricKit diagnostic payload received")
        }
    }
}
