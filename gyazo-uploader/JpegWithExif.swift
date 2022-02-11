//
//  JpegWithExif.swift
//  gyazo-uploader
//
//  Created by TeramotoDaiki on 2022/02/11.
//

import Foundation
import CoreLocation
import ImageIO
import UIKit
import UniformTypeIdentifiers
import MobileCoreServices

enum ExifError: Error {
    case CGImageDestinationCreateWithDataReturnsNil
}

func toJpegWithExif(image: UIImage, metadata: NSDictionary, location: CLLocation?) -> Data {
    return autoreleasepool(invoking: { () -> Data in
        let data = NSMutableData()
        let options = metadata.mutableCopy() as! NSMutableDictionary
        options[kCGImageDestinationLossyCompressionQuality] = CGFloat(1) // compressionQuality?
        
        // Convert CLLocation into NSMutableDictionary
        if let location = location {
            let gpsData = NSMutableDictionary()
            let altitudeRef = Int(location.altitude < 0.0 ? 1 : 0)
            let latitudeRef = location.coordinate.latitude < 0.0 ? "S" : "N"
            let longitudeRef = location.coordinate.longitude < 0.0 ? "W" : "E"
            
            // GPS metadata
            gpsData[kCGImagePropertyGPSLatitude] = abs(location.coordinate.latitude)
            gpsData[kCGImagePropertyGPSLatitudeRef] = latitudeRef
            gpsData[kCGImagePropertyGPSLongitude] = abs(location.coordinate.longitude)
            gpsData[kCGImagePropertyGPSLongitudeRef] = longitudeRef
            gpsData[kCGImagePropertyGPSAltitude] = Int(abs(location.altitude))
            gpsData[kCGImagePropertyGPSAltitudeRef] = altitudeRef
            gpsData[kCGImagePropertyGPSDateStamp] = location.timestamp.isoDate()
            gpsData[kCGImagePropertyGPSTimeStamp] = location.timestamp.isoTime()
            gpsData[kCGImagePropertyGPSVersion] = "2.2.0.0"
            
            options[kCGImagePropertyGPSDictionary] = gpsData
        }
        
        let imageDestinationRef = CGImageDestinationCreateWithData(data as CFMutableData, kUTTypeJPEG, 1, nil)!
        CGImageDestinationAddImage(imageDestinationRef, image.cgImage!, options)
        CGImageDestinationFinalize(imageDestinationRef)
        return data as Data
    })
}


extension Date {
    func isoDate() -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 3600 * 9)
        f.dateFormat = "yyyy:MM:dd"
        return f.string(from: self)
    }
    
    func isoTime() -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 3600 * 9)
        f.dateFormat = "HH:mm:ss.SSSSSS"
        return f.string(from: self)
    }
}
