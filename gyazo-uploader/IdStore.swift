//
//  IdStore.swift
//  gyazo-uploader
//
//  Created by TeramotoDaiki on 2022/02/06.
//

import Foundation

enum IdStoreError: Error {
    case FileIsNotUTF8
}

// localIdentifier_1,gyazoId_1
// localIdentifier_2,gyazoId_2
// ...

// localIdentifiers of uploaded assets
class IdStore: ObservableObject {
    @Published var identifiers: [String] = [] // Viewから購読されるlocalIdentifierだけの配列
    private var rows: [String] = [] // CSVデータの実体
    
    private static func fileURL() throws -> URL {
        // save at document dicretory of this user
        try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("identifiers.csv") // file name
    }
    
    func load() async throws {
        identifiers = [] // be empty
        return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) in
            // load from file
            DispatchQueue.global(qos: .background).async {
                do {
                    // read file
                    let fileURL = try IdStore.fileURL()
                    print(fileURL.absoluteString)
                    guard let file = try? FileHandle(forReadingFrom: fileURL) else {
                        // file not exists
                        DispatchQueue.main.async {
                            continuation.resume()
                        }
                        return
                    }
                    guard let csv = String(data: file.availableData, encoding: .utf8) else {
                        // invalid file
                        DispatchQueue.main.async {
                            continuation.resume(throwing: IdStoreError.FileIsNotUTF8)
                        }
                        return
                    }
                    let rows = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
                    let identifiers = rows.map { $0.components(separatedBy: ",")[0].trimmingCharacters(in: .whitespacesAndNewlines) }
                    DispatchQueue.main.async {
                        self.rows = rows
                        self.identifiers = identifiers
                        continuation.resume()
                    }
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: error)
                    }
                }
            }
        })
    }
    
    func save(completion: @escaping (Result<Int, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let data = self.rows.joined(separator: "\n").data(using: .utf8)
                let outfile = try IdStore.fileURL()
                try data!.write(to: outfile)
                DispatchQueue.main.async {
                    completion(.success(self.rows.count))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func append(identifier: String, gyazoId: String) async -> Int {
        self.rows.append("\(identifier),\(gyazoId)")
        
        return await withCheckedContinuation({
            (continuation: CheckedContinuation<Int, Never>) in
            save(completion: { result in
                switch (result) {
                case .success(let count):
                    continuation.resume(returning: count)
                    self.identifiers.append(identifier)
                case .failure(let error):
                    fatalError(error.localizedDescription)
                }
            })
        })
    }
    
}
