import Foundation
import ActivityKit
import CoreLocation

@available(iOS 16.2, *)
extension SimRaRecordingActivityManager {
    
    func updateActivityWithRoute(_ locations: [CLLocationCoordinate2D]) {
        guard #available(iOS 16.2, *) else { return }
        
        Task {
            let routePoints = locations.map {
                SimRaRecordingAttributes.RoutePoint(
                    latitude: $0.latitude,
                    longitude: $0.longitude
                )
            }
            
            var contentState = currentActivity?.content.state ?? SimRaRecordingAttributes.ContentState()
            contentState.routePoints = Array(routePoints.suffix(50))
            
            await updateActivity(with: contentState)
        }
    }
    
    func recordHazardInActivity(
        at coordinate: CLLocationCoordinate2D
    ) {
        guard #available(iOS 16.2, *) else { return }
        
        Task {
            let routePoint = SimRaRecordingAttributes.RoutePoint(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            
            var contentState = currentActivity?.content.state ?? SimRaRecordingAttributes.ContentState()
            contentState.incidents += 1
            contentState.lastHazardLocation = routePoint
            
            await updateActivity(with: contentState)
        }
    }
    
    @MainActor
    private func updateActivity(with contentState: SimRaRecordingAttributes.ContentState) async {
        guard #available(iOS 16.2, *) else { return }
        
        guard let activity = currentActivity else { return }
        
        do {
            try await activity.update(using: contentState)
        } catch {
            print("Failed to update activity: \(error)")
        }
    }
}
