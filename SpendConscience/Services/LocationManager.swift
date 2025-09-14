//
//  LocationManager.swift
//  SpendConscience
//
//  Created by AI Assistant on 9/14/2025.
//

import Foundation
import CoreLocation
import SwiftUI

@MainActor
class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var locationError: LocationError?
    
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    
    enum LocationError: LocalizedError {
        case denied
        case unavailable
        case timeout
        case accuracyReduced
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .denied:
                return "Location access denied. Please enable location services in Settings."
            case .unavailable:
                return "Location services are unavailable."
            case .timeout:
                return "Location request timed out. Please try again."
            case .accuracyReduced:
                return "Location accuracy is reduced. Restaurant recommendations may be less precise."
            case .unknown(let error):
                return "Location error: \(error.localizedDescription)"
            }
        }
    }
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // Only update if moved 100m
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationError = .denied
        case .authorizedWhenInUse, .authorizedAlways:
            // Already authorized
            break
        @unknown default:
            locationError = .unknown(NSError(domain: "LocationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown authorization status"]))
        }
    }
    
    func requestWhenInUseAuthorizationAsync() async -> CLAuthorizationStatus {
        // If already determined, return current status
        if authorizationStatus != .notDetermined {
            return authorizationStatus
        }
        
        return await withCheckedContinuation { continuation in
            self.authorizationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.denied
        }
        
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationError.unavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            
            // Set timeout for location request
            Task {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                if self.locationContinuation != nil {
                    self.locationContinuation?.resume(throwing: LocationError.timeout)
                    self.locationContinuation = nil
                }
            }
            
            locationManager.requestLocation()
        }
    }
    
    func checkLocationPermission() -> Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    private func clearLocationError() {
        locationError = nil
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            
            self.currentLocation = location
            self.clearLocationError()
            
            if let continuation = self.locationContinuation {
                continuation.resume(returning: location)
                self.locationContinuation = nil
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let locationError: LocationError
            
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    locationError = .denied
                case .locationUnknown, .network:
                    locationError = .unavailable
                default:
                    locationError = .unknown(error)
                }
            } else {
                locationError = .unknown(error)
            }
            
            self.locationError = locationError
            
            if let continuation = self.locationContinuation {
                continuation.resume(throwing: locationError)
                self.locationContinuation = nil
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.authorizationStatus = status
            
            switch status {
            case .denied, .restricted:
                self.locationError = .denied
            case .authorizedWhenInUse, .authorizedAlways:
                self.clearLocationError()
                
                // Check for reduced accuracy when authorized
                if #available(iOS 14.0, *) {
                    if manager.accuracyAuthorization == .reducedAccuracy {
                        self.locationError = .accuracyReduced
                    }
                }
            default:
                break
            }
            
            // Resume authorization continuation if waiting
            if let continuation = self.authorizationContinuation {
                continuation.resume(returning: status)
                self.authorizationContinuation = nil
            }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationManager(manager, didChangeAuthorization: manager.authorizationStatus)
    }
}
