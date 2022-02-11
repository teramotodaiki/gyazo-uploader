//
//  JpegWithExif.swift
//  gyazo-uploader
//
//  Created by TeramotoDaiki on 2022/02/11.
//

import CoreImage
import MobileCoreServices

extension CIImage {
    func toJpegWithExif() -> Data {
        return autoreleasepool(invoking: { () -> Data in
            let data = NSMutableData()
            let options = NSDictionary(dictionary: self.properties, copyItems: true)
            
            let imageDestinationRef = CGImageDestinationCreateWithData(data as CFMutableData, kUTTypeJPEG, 1, nil)!
            let context = CIContext()
            let cgImage = context.createCGImage(self, from: self.extent)!
            CGImageDestinationAddImage(imageDestinationRef, cgImage, options)
            CGImageDestinationFinalize(imageDestinationRef)
            return data as Data
        })
    }
}

