import Foundation

@available(iOS 16.0, *)
enum HazardType: String, Codable {
    case pothole = "Pothole"
    case tailgating = "Tailgating"
    case illegalParking = "Illegal Parking"
    case dooring = "Dooring"
    case turningAccident = "Turning Accident"
    case oncomingTraffic = "Oncoming Traffic"
    case closePassing = "Close Passing"
    case sidestep = "Sidestep"
}

@available(iOS 16.0, *)
enum TrafficParticipantType: String, Codable {
    case car = "Car"
    case pedestrian = "Pedestrian"
    case truck = "Truck"
    case bus = "Bus"
    case motorcycle = "Motorcycle"
    case bicycle = "Bicycle"
}

@available(iOS 16.0, *)
enum HazardSource: String, Codable {
    case onDeviceAI = "On-Device AI"
    case onlineAI = "Online AI"
    case manual = "Manual"
}

@available(iOS 16.0, *)
struct DetectedHazard: Codable {
    let id: String
    let timestamp: Date
    let coordinate: CodableLocation
    let hazardType: HazardType?
    let participant: TrafficParticipantType?
    let source: HazardSource
    let confidence: Double
    
    init(
        id: String = UUID().uuidString,
        timestamp: Date = .now,
        coordinate: CodableLocation,
        hazardType: HazardType? = nil,
        participant: TrafficParticipantType? = nil,
        source: HazardSource = .manual,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.coordinate = coordinate
        self.hazardType = hazardType
        self.participant = participant
        self.source = source
        self.confidence = confidence
    }
}

@available(iOS 16.0, *)
struct CodableLocation: Codable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
