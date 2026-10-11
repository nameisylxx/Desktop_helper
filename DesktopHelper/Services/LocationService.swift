import CoreLocation

/// 获取一次当前位置（只用来查天气，精度到公里级就够）
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum LocationError: LocalizedError {
        case denied, timeout

        var errorDescription: String? {
            switch self {
            case .denied: "Location access denied"
            case .timeout: "Location timed out"
            }
        }
    }

    private let manager = CLLocationManager()
    private var waiters: [CheckedContinuation<CLLocation, Error>] = []
    private var requestToken = UUID()
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func currentLocation() async throws -> CLLocation {
        // 15 分钟内的位置直接复用
        if let lastLocation, -lastLocation.timestamp.timeIntervalSinceNow < 900 {
            return lastLocation
        }
        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
            guard waiters.count == 1 else { return }

            let token = UUID()
            requestToken = token
            begin()
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
                guard let self, self.requestToken == token else { return }
                self.finish(.failure(LocationError.timeout))
            }
        }
    }

    private func begin() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: finish(.failure(LocationError.denied))
        default: manager.requestLocation()
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        requestToken = UUID()
        if case let .success(location) = result { lastLocation = location }
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume(with: result) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard !waiters.isEmpty else { return }
            switch manager.authorizationStatus {
            case .notDetermined: break
            case .denied, .restricted: finish(.failure(LocationError.denied))
            default: manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        MainActor.assumeIsolated { finish(.success(location)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { finish(.failure(error)) }
    }
}
