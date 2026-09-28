import CoreLocation
import Flutter
import UIKit

/// Owns iOS region registration and a small app-private candidate outbox.
/// It deliberately persists only routine geofence evidence; Supabase session
/// restoration and authenticated upload remain in the shared Dart drain.
final class GeofenceRegionManager: NSObject, CLLocationManagerDelegate {
  private static let channelName = "safepath/geofencing"
  private static let maximumRegions = 20
  private static let maximumCandidates = 100
  private static let outboxKey = "safepath_geofence_pending_candidates_v1"

  private let defaults = UserDefaults.standard
  private let locationManager = CLLocationManager()
  private weak var application: UIApplication?
  private var channel: FlutterMethodChannel?
  private var backgroundTask = UIBackgroundTaskIdentifier.invalid

  override init() {
    super.init()
    locationManager.delegate = self
  }

  func configure(
    application: UIApplication,
    binaryMessenger: FlutterBinaryMessenger,
    launchedForLocation: Bool
  ) {
    self.application = application
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel

    if launchedForLocation {
      // iOS has relaunched the process for a monitored region. Keep the
      // window bounded while Flutter initializes and restores Supabase auth;
      // the Dart candidate drain remains the only upload path.
      beginRelaunchDrainWindow()
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCapability":
      result(["status": capabilityStatus()])
    case "requestBackgroundCapability":
      requestBackgroundCapability()
      result(["status": capabilityStatus()])
    case "replaceMonitoredZones":
      replaceMonitoredZones(call.arguments, result: result)
    case "drainPendingCandidates":
      result(readOutbox())
    case "acknowledgeCandidate":
      acknowledge(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func capabilityStatus() -> String {
    guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
      return "unavailable"
    }
    switch locationManager.authorizationStatus {
    case .authorizedAlways:
      return "ready"
    case .notDetermined:
      return "needsLocationPermission"
    case .authorizedWhenInUse:
      return "needsBackgroundPermission"
    case .denied, .restricted:
      return "unavailable"
    @unknown default:
      return "unavailable"
    }
  }

  private func requestBackgroundCapability() {
    switch locationManager.authorizationStatus {
    case .notDetermined:
      locationManager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse:
      locationManager.requestAlwaysAuthorization()
    default:
      break
    }
  }

  private func replaceMonitoredZones(_ arguments: Any?, result: @escaping FlutterResult) {
    guard capabilityStatus() == "ready" else {
      result(FlutterError(code: "capability_unavailable", message: "Background location capability is not ready.", details: capabilityStatus()))
      return
    }
    guard let payload = arguments as? [String: Any], let zones = payload["zones"] as? [[String: Any]] else {
      result(FlutterError(code: "invalid_arguments", message: "zones are required.", details: nil))
      return
    }
    guard zones.count <= Self.maximumRegions else {
      result(FlutterError(code: "zone_limit", message: "iOS supports at most \(Self.maximumRegions) monitored zones.", details: nil))
      return
    }

    let regions: [CLCircularRegion]
    do {
      regions = try zones.map(makeRegion)
    } catch {
      result(FlutterError(code: "invalid_zone", message: error.localizedDescription, details: nil))
      return
    }

    locationManager.monitoredRegions.forEach(locationManager.stopMonitoring)
    regions.forEach(locationManager.startMonitoring)
    result(nil)
  }

  private func makeRegion(_ zone: [String: Any]) throws -> CLCircularRegion {
    guard let zoneId = zone["zoneId"] as? String,
          let generation = (zone["generation"] as? NSNumber)?.intValue,
          let latitude = (zone["latitude"] as? NSNumber)?.doubleValue,
          let longitude = (zone["longitude"] as? NSNumber)?.doubleValue,
          let radius = (zone["radiusMeters"] as? NSNumber)?.doubleValue,
          !zoneId.isEmpty,
          generation > 0,
          (-90...90).contains(latitude),
          (-180...180).contains(longitude),
          radius > 0 else {
      throw NSError(domain: "SafePathGeofence", code: 1, userInfo: [NSLocalizedDescriptionKey: "A zone is invalid."])
    }
    let region = CLCircularRegion(
      center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
      radius: radius,
      identifier: "\(zoneId):\(generation)"
    )
    region.notifyOnEntry = true
    region.notifyOnExit = true
    return region
  }

  private func acknowledge(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let payload = arguments as? [String: Any], let eventId = payload["eventId"] as? String, !eventId.isEmpty else {
      result(FlutterError(code: "invalid_arguments", message: "eventId is required.", details: nil))
      return
    }
    writeOutbox(readOutbox().filter { ($0["eventId"] as? String) != eventId })
    result(nil)
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    persist(region: region, transition: "enter", location: manager.location)
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    persist(region: region, transition: "exit", location: manager.location)
  }

  func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
    // Preserve the failure before Dart runs. It is not treated as a transition
    // and therefore cannot produce routine activity or alter SOS behavior.
    persist(region: region, transition: "error", location: manager.location, errorCode: (error as NSError).code)
  }

  private func persist(region: CLRegion?, transition: String, location: CLLocation?, errorCode: Int? = nil) {
    var candidate: [String: Any] = [
      "eventId": UUID().uuidString,
      "requestId": region?.identifier ?? "",
      "transition": transition,
      "occurredAtEpochMs": Int(Date().timeIntervalSince1970 * 1000),
    ]
    // Never invent a coordinate: absent fields map to nullable Dart values.
    if let location {
      candidate["latitude"] = location.coordinate.latitude
      candidate["longitude"] = location.coordinate.longitude
      candidate["accuracyMeters"] = location.horizontalAccuracy
    }
    if let errorCode { candidate["errorCode"] = errorCode }
    var outbox = readOutbox()
    outbox.append(candidate)
    writeOutbox(Array(outbox.suffix(Self.maximumCandidates)))
  }

  private func readOutbox() -> [[String: Any]] {
    defaults.array(forKey: Self.outboxKey) as? [[String: Any]] ?? []
  }

  private func writeOutbox(_ candidates: [[String: Any]]) {
    defaults.set(candidates, forKey: Self.outboxKey)
  }

  private func beginRelaunchDrainWindow() {
    guard backgroundTask == .invalid, let application else { return }
    backgroundTask = application.beginBackgroundTask(withName: "SafePathGeofenceDrain") { [weak self] in
      self?.endRelaunchDrainWindow()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
      self?.endRelaunchDrainWindow()
    }
  }

  private func endRelaunchDrainWindow() {
    guard backgroundTask != .invalid else { return }
    application?.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }
}
