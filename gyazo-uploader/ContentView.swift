//
//  ContentView.swift
//  gyazo-uploader
//
//  Created by TeramotoDaiki on 2022/01/19.
//

import SwiftUI
import CoreData
import PhotosUI

struct LocalImageAsset {
    var localIdentifier: String
    var image: UIImage
}

enum AppPhase {
    case initialized // request authorization for photo library
    case denied // access denied
    case uploadReady // fetched assets from photo library
    case uploading // uploading images to gyazo
    case complete // upload completed
}

enum AppError: Error {
    case invalidPhotoData
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State var appPhase: AppPhase = .initialized
    var statusMessage: String {
        switch appPhase {
        case .initialized:
            return "Requesting to access your photos..."
        case .denied:
            return "Please allow to access your photos"
        case .uploadReady:
            return "\(assets.count) photos will upload"
        case .uploading:
            return "\(uploadPhotoNum)/\(assets.count) photos uploaded"
        case .complete:
            return "Completed! \(uploadPhotoNum)/\(assets.count) photos uploaded!"
        }
    }
    @State var assets: [PHAsset] = []
    @State var uploadPhotoNum = 0
    @State var uploadingImage: UIImage? = nil
    
    var body: some View {
        VStack {
            Text(statusMessage).padding()
            if (appPhase == .uploadReady) {
                Button("Upload!") {
                    appPhase = .uploading
                    Task {
                        await uploadAllPhotos()
                        appPhase = .complete
                    }
                }
            }
            if uploadingImage != nil {
                Image(uiImage: uploadingImage!)
                    .resizable(resizingMode: .stretch)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 128)
            }
        }.onAppear(perform: viewDidLoad)
    }
    
    
    private func viewDidLoad() {
        if (appPhase != .initialized) {return} // for Preview

        // Request permission to access photo library
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [self] (status) in
            DispatchQueue.main.async { [self] in
                if(status == .authorized) {
                    onAuthorized()
                    appPhase = .uploadReady
                } else {
                    appPhase = .denied
                }
            }
        }
    }
    
    // will call after PHPhotoLibrary.requestAuthorization
    private func onAuthorized() {
        let result = PHAsset.fetchAssets(with: .image, options: nil)
        
        let jikkenLimit = 10 // no spam in experiment
        let count = min(jikkenLimit, result.count)
        
        assets = result.objects(at: IndexSet(0..<count))
    }
    
    private func uploadAllPhotos() async {
        uploadPhotoNum = 0
        for asset in assets {
            // asset.localIdentifier
            let image = await requestImageAsync(asset: asset) // get photo from storage or icloud
            uploadingImage = image // show uploading image
            do {
                _ = try await uploadImage(image: image)
                uploadPhotoNum += 1
            } catch {
                print(error)
                print("Unknown error was occured")
            }
        }
    }
    
    private func requestImageAsync(asset: PHAsset) async -> UIImage {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        
        return await withCheckedContinuation({
            (continuation: CheckedContinuation<UIImage, Never>) in
                // which is better requestImage or requestImageDataAndOrientation?
                manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options, resultHandler: { (image, _) in
                        // TODO: support image is nil
                        continuation.resume(returning: image!)
            })
        })
    }
    
    private func uploadImage(image: UIImage) async throws -> String {
        let url = "https://upload.gyazo.com/api/upload"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\"\(boundary)\"", forHTTPHeaderField: "Content-Type")
        

        var formData = Data()
        
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)

        formData.append("Content-Disposition: form-data; name=\"access_token\"\r\n\r\n".data(using: .utf8)!)
        formData.append("\(getAccessToken())\r\n".data(using: .utf8)!)
        
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)

        formData.append("Content-Disposition: form-data; name=\"imagedata\";  filename=\"gyazo_agetarou_sample.png\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        let imageData = image.pngData()
        formData.append(imageData!)
        formData.append("\r\n".data(using: .utf8)!)

        formData.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.setValue("\(formData.count)", forHTTPHeaderField:"Content-Length")
        request.httpBody = formData
        
        let session = URLSession.shared
        let (data, _) = try await session.upload(for: request, from: formData)
        let json = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as! Dictionary<String, String>
        print(json)
        return json["image_id"]! // can be permalink_url(gyazo.com), url(i.gyazo.com)
    }
}

private func getAccessToken() -> String {
    var keys: NSDictionary?

    if let path = Bundle.main.path(forResource: "Info", ofType: "plist") {
        keys = NSDictionary(contentsOfFile: path)
    }
    let accessToken = keys?["GYAZO_ACCESS_TOKEN"] as? String
    return accessToken ?? ""
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let dummyAssets: [PHAsset] = Array(repeating: PHAsset(), count: 20)
            let dummyImage = UIImage(imageLiteralResourceName: "tani")
            ContentView(appPhase: .uploading, assets: dummyAssets, uploadingImage: dummyImage)
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
