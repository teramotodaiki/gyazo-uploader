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
                    Image(uiImage: images[index])
                        .resizable(resizingMode: .stretch)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128, height: 128)
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
    
    private func showUI() {
        let result = PHAsset.fetchAssets(with: nil)
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        
        options.deliveryMode = .highQualityFormat
        let assets = result.objects(at: IndexSet(integersIn: 0...10))
        for asset in assets {
            manager.requestImage(for: asset, targetSize: CGSize(width: 128, height: 128), contentMode: .aspectFit, options: options, resultHandler: { (image, _) in
                if (image == nil) { return }
                images.append(image!)
            })
        }
        
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
