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


// localIdentifiers of uploaded assets
class IdStore: ObservableObject {
    @Published var identifiers: [String] = []
    
    private static func fileURL() throws -> URL {
        // save at document dicretory of this user
        try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("identifiers.csv") // file name
    }
    
    static func load() async throws -> [String] {
        return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<[String], Error>) in
            // load from file
            DispatchQueue.global(qos: .background).async {
                do {
                    // read file
                    let fileURL = try fileURL()
                    print(fileURL.absoluteString)
                    guard let file = try? FileHandle(forReadingFrom: fileURL) else {
                        // file not exists
                        DispatchQueue.main.async {
                            continuation.resume(returning: [])
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
                    let identifiers = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
                    DispatchQueue.main.async {
                        continuation.resume(returning: identifiers)
                    }
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: error)
                    }
                }
            }
        })
    }
    
    static func save(identifiers: [String], completion: @escaping (Result<Int, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let data = identifiers.joined(separator: "\n").data(using: .utf8)
                let outfile = try fileURL()
                try data?.write(to: outfile)
                DispatchQueue.main.async {
                    completion(.success(identifiers.count))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func append(identifier: String) async -> Int {
        identifiers.append(identifier)
        return await withCheckedContinuation({
            (continuation: CheckedContinuation<Int, Never>) in
            IdStore.save(identifiers: identifiers, completion: { result in
                switch (result) {
                case .success(let count):
                    continuation.resume(returning: count)
                case .failure(let error):
                    fatalError(error.localizedDescription)
                }
            })
        })
    }
    
}
