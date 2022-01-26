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

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    @State var imageAssets: [LocalImageAsset] = []
    
    var body: some View {
        let columns: [GridItem] = [
            GridItem(.adaptive(minimum: 100, maximum: .infinity))
        ]
        ScrollView {
            LazyVGrid(columns: columns) {
                ForEach((0..<imageAssets.count), id: \.self) { index in
                    let imageAsset = imageAssets[index]
                    Image(uiImage: imageAsset.image)
                        .resizable(resizingMode: .stretch)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128, height: 128)
                        .onTapGesture{
                            uploadImage(image: imageAsset.image)
                        }
                 }
            }.font(.largeTitle)
        }.onAppear(perform: viewDidLoad)
    }
    
    
    private func viewDidLoad() {
        // Request permission to access photo library
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [self] (status) in
            DispatchQueue.main.async { [self] in
                if(status == .authorized) {
                    showUI()
                }
            }
        }
    }
    
    private func uploadImage(image: UIImage) {
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
        let task = session.uploadTask(with: request, from: formData, completionHandler: { data, response, error -> Void in
            if (error != nil) {
                return
            }
//            print("response: \(String(data: data!, encoding: .utf8)!)")
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: .fragmentsAllowed)
                print(json)
            } catch {
                print("Parse failed.")
            }
        })
        task.resume()
        
    }
    
    private func showUI() {
        let result = PHAsset.fetchAssets(with: nil)
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        
        options.deliveryMode = .highQualityFormat
        result.enumerateObjects({ (asset, _, _) in
            manager.requestImage(for: asset, targetSize: CGSize(width: 128, height: 128), contentMode: .aspectFit, options: options, resultHandler: { (image, _) in
                if (image == nil) { return }
                let imageAsset = LocalImageAsset(localIdentifier: asset.localIdentifier, image: image!)
                imageAssets.append(imageAsset)
            })
        })
    }
    

    private func addItem() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

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
            let sampleAssets = Array(repeating: LocalImageAsset(
                localIdentifier: UUID().uuidString, image:
                UIImage(imageLiteralResourceName: "tani")), count: 20)
            ContentView(imageAssets: sampleAssets ).environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
