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

func toJpegWithExif(image: CIImage) -> Data {
    return autoreleasepool(invoking: { () -> Data in
        let data = NSMutableData()
        let options = NSDictionary(dictionary: image.properties, copyItems: true)
        
        let imageDestinationRef = CGImageDestinationCreateWithData(data as CFMutableData, kUTTypeJPEG, 1, nil)!
        let context = CIContext()
        let cgImage = context.createCGImage(image, from: image.extent)!
        CGImageDestinationAddImage(imageDestinationRef, cgImage, options)
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
