#!/usr/bin/env swift

import Foundation

// Simulate the exact iOS request
struct FinancialQuestionRequest: Codable {
    let query: String
    let userId: String
    let accessToken: String?
    
    init(query: String, userId: String = "ios-user", accessToken: String? = nil) {
        self.query = query
        self.userId = userId
        self.accessToken = accessToken
    }
}

// Encoder with same configuration as iOS app
let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.keyEncodingStrategy = .convertToSnakeCase
    return e
}()

// Create the same request
let request = FinancialQuestionRequest(query: "Can I afford a $50 dinner?", userId: "ios-user")
let requestData = try encoder.encode(request)

print("iOS app would send this JSON:")
print(String(data: requestData, encoding: .utf8) ?? "Failed to encode")

// Test with URLSession like iOS app
let url = URL(string: "https://spendconscience-agents-g9og3bwk9-sehej-jains-projects.vercel.app/ask")!
var urlRequest = URLRequest(url: url)
urlRequest.httpMethod = "POST"
urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
urlRequest.httpBody = requestData

print("\nSending request...")

let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
    if let error = error {
        print("Error: \(error)")
        exit(1)
    }
    
    guard let httpResponse = response as? HTTPURLResponse else {
        print("Invalid response type")
        exit(1)
    }
    
    print("Status code: \(httpResponse.statusCode)")
    print("Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
    
    guard let data = data else {
        print("No data received - this is the iOS error!")
        exit(1)
    }
    
    print("Data length: \(data.count)")
    if let responseString = String(data: data, encoding: .utf8) {
        print("Response: \(responseString)")
    } else {
        print("Could not decode response as UTF-8")
    }
    
    exit(0)
}

task.resume()

// Keep the script running
RunLoop.main.run()