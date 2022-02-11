//
//  ContentView.swift
//  gyazo-uploader
//
//  Created by TeramotoDaiki on 2022/01/19.
//

import SwiftUI
import CoreData
import PhotosUI

enum AppPhase {
    case initialized // request authorization for photo library
    case denied // access denied
    case authorized // authorized
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
        case .authorized:
            return "Find new photos..."
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
    @StateObject private var idStore = IdStore() // subscribe IdStore
    
    var body: some View {
        VStack {
            Text(statusMessage)
            if (appPhase == .uploadReady) {
                Button("Upload!") {
                    appPhase = .uploading
                    Task {
                        await uploadAllPhotos()
                        appPhase = .complete
                    }
                }
                .padding()
            }
            Text("Total upload: \(idStore.identifiers.count)")
            if uploadingImage != nil {
                Image(uiImage: uploadingImage!)
                    .resizable(resizingMode: .stretch)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 128)
                    .padding()
            }
            if (appPhase == .complete || appPhase == .uploadReady) {
                Button("Reload") {
                    appPhase = .authorized
                    Task {
                        await checkForUpload()
                    }
                }
            }
        }.onAppear(perform: viewDidLoad)
    }
    
    
    private func viewDidLoad() {
        if (appPhase != .initialized) {return}
        
        // Request permission to access photo library
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [self] (status) in
            DispatchQueue.main.async { [self] in
                if(status == .authorized) {
                    appPhase = .authorized
                    Task {
                        await checkForUpload()
                    }
                } else {
                    appPhase = .denied
                }
            }
        }
    }
    
    // will call after PHPhotoLibrary.requestAuthorization
    private func checkForUpload() async {
        do {
            // Load identifiers of uploaded photos from file
            let identifiers = try await IdStore.load()
            DispatchQueue.main.async {
                idStore.identifiers = identifiers
            }
            
            let result = PHAsset.fetchAssets(with: .image, options: nil)
            
            let jikkenLimit = 2 // no spam in experiment
            let count = min(jikkenLimit, result.count)
            
            assets = result.objects(at: IndexSet(0..<count)).filter { !idStore.identifiers.contains($0.localIdentifier) }
            
            appPhase = .uploadReady
        } catch {
            print("Failed to check for upload")
            print(error)
        }
    }
    
    private func uploadAllPhotos() async {
        uploadPhotoNum = 0
        for asset in assets {
            do {
                // upload to Gyazo
                _ = try await uploadImageAsset(asset: asset) // get photo from storage or icloud and upload
                // mark as uploaded
                _ = await idStore.append(identifier: asset.localIdentifier)
                uploadPhotoNum += 1
            } catch {
                print(error)
                print("Unknown error was occured")
            }
        }
    }
    
    private func requestImageAsync(asset: PHAsset) async -> CIImage {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true // download asset metadata from iCloud if needed
        
        return await withCheckedContinuation({ (continuation: CheckedContinuation<CIImage, Never>) in
            asset.requestContentEditingInput(with: options, completionHandler: { (input, _) in
                let url = input?.fullSizeImageURL!
                let ciImage = CIImage(contentsOf: url!)
                // TODO: support image is nil
                continuation.resume(returning: ciImage!)
            })
        })
    }

    
    private func uploadImageAsset(asset: PHAsset) async throws -> String {
        let image = await requestImageAsync(asset: asset)
        let imageData = image.toJpegWithExif()
        uploadingImage = UIImage(data: imageData) // show uploading image
        
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

        formData.append("Content-Disposition: form-data; name=\"app\"\r\n\r\n".data(using: .utf8)!)
        formData.append("gyazo-uploader iOS\r\n".data(using: .utf8)!)
        
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        
        if let created = asset.creationDate {
            formData.append("Content-Disposition: form-data; name=\"created_at\"\r\n\r\n".data(using: .utf8)!)
            let unixtime = created.timeIntervalSince1970
            formData.append("\(unixtime)\r\n".data(using: .utf8)!)
            
            formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        }

        formData.append("Content-Disposition: form-data; name=\"imagedata\";  filename=\"gyazo_agetarou_sample.jpg\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: image/jpg\r\n\r\n".data(using: .utf8)!)
        formData.append(imageData)
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
            // Ready to upload
            ContentView(appPhase: .uploadReady, assets: dummyAssets)
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            // Uploading
            ContentView(appPhase: .uploading, assets: dummyAssets, uploadingImage: dummyImage)
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
