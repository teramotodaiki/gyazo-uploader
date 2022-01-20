//
//  ContentView.swift
//  gyazo-uploader
//
//  Created by TeramotoDaiki on 2022/01/19.
//

import SwiftUI
import CoreData
import PhotosUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    @State var images: [UIImage] = []
    
    var body: some View {
        let columns: [GridItem] = [
            GridItem(.adaptive(minimum: 100, maximum: .infinity))
        ]
        ScrollView {
            LazyVGrid(columns: columns) {
                ForEach((0..<images.count), id: \.self) { index in
                    let image = images[index]
                    Image(uiImage: image)
                        .resizable(resizingMode: .stretch)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128, height: 128)
                        .onTapGesture{
                            uploadImage(image: image)
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
        var request = URLRequest(url: URL(string: "http://localhost:3000")!)
        request.httpMethod = "GET"
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
//            print(response!)
            do {
                let json = try JSONSerialization.jsonObject(with: data!) as! Dictionary<String, AnyObject>
                print(json)
            } catch {
                print("error")
            }
        })
        task.resume()
        
        print("clicked")
    }
    
    private func showUI() {
        let result = PHAsset.fetchAssets(with: nil)
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        
        options.deliveryMode = .highQualityFormat
        result.enumerateObjects({ (asset, _, _) in
            manager.requestImage(for: asset, targetSize: CGSize(width: 128, height: 128), contentMode: .aspectFit, options: options, resultHandler: { (image, _) in
                if (image == nil) { return }
                images.append(image!)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let sampleImages = Array(repeating: UIImage(imageLiteralResourceName: "tani"), count: 20)
            ContentView(images: sampleImages ).environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
