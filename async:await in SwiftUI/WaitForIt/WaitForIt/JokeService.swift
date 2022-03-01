/// Copyright (c) 2021 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation

actor JokeServiceActor {
  private var loadedJoke = Joke.empty
  
  private var url: URL {
    // swiftlint:disable:next force_unwrapping
    urlComponents.url!
  }

  private var urlComponents: URLComponents {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.chucknorris.io"
    components.path = "/jokes/random"
    components.setQueryItems(with: ["category": "dev"])
    return components
  }
  
  func load() async throws -> Joke {
    let (data, response) = try await URLSession.shared.data(from: url)
    
    guard
      let httpResponse = response as? HTTPURLResponse,
      httpResponse.statusCode.isSuccessfulHtttpStatusCode
    else { throw DownloadError.statusNotOk }
    
    guard
      let joke = try? JSONDecoder().decode(Joke.self, from: data)
    else { throw DownloadError.decoderError }
    
    loadedJoke = joke
    return loadedJoke
  }
}

class JokeService: ObservableObject {
  @Published private(set) var joke = "Joke appears here"
  @Published private(set) var isFetching = false
  @Published private(set) var previousJokes = [String]()
  
  private let store = JokeServiceActor()

  public init() { }
}

enum DownloadError: Error {
  case statusNotOk
  case decoderError
}

extension Int {
  var isSuccessfulHtttpStatusCode: Bool {
    200..<300 ~= self
  }
}

extension JokeService {
  
  // With this we call load and this thread is suspended
  // Freeing up UI
  // load is called on background thread and when it's done
  // Picks up back on the main thread
  @MainActor
  func fetchJoke() async throws {
    isFetching = true
    
    // Called when succesful or an error thrown
    defer { isFetching = false }
    
    // Problem now is we're using a background thread
    // Even though we started by calling from a SwiftUI Main thread
    let loadedJoke = try await store.load()
    joke = loadedJoke.value
    previousJokes.append(loadedJoke.value)
    
    /*
     * Th_s called concurrent binding because parent task continues
     * execution after creating a child task with the data(from: url) call on another
     * thread. _d inherits parent's priority level and local variables.
     *
    async let (data, response) = URLSession.shared.data(from: url)
    try! await (data, response)
     */
    
    /*
     * Sequential binding is combing the async and await to one line
     * This won't create a child task like above. Instead it runs sequentially in the parent
     */
    
    /*
     * Moving to Actor
     
    let (data, response) = try await URLSession.shared.data(from: url)
    
    guard
      let httpResponse = response as? HTTPURLResponse,
      httpResponse.statusCode.isSuccessfulHtttpStatusCode
    else { throw DownloadError.statusNotOk }
    
    guard
      let joke = try? JSONDecoder().decode(Joke.self, from: data)
    else { throw DownloadError.decoderError }
     
    *
    */

    // But what about dispatch to Main
    // Not to Fear
    // The Button was created with MainActor which is just like DispatchQueue.main
    // All SwiftUI Views run on MainActor
    // So when we made the async call with this it delivers on the main thread
    // if you want something to run not on MainActor
    // You need to create your own!
//    self.joke = joke.value
    
    /*
     * Old way before async/await changes
     *
    URLSession.shared.dataTask(with: url) { data, response, error in
      defer {
        DispatchQueue.main.async {
          self.isFetching = false
        }
      }
      if let data = data, let response = response as? HTTPURLResponse {
        print(response.statusCode)
        if let decodedResponse = try? JSONDecoder().decode(Joke.self, from: data) {
          DispatchQueue.main.async {
            self.joke = decodedResponse.value
          }
          return
        }
      }
      print("Joke fetch failed: \(error?.localizedDescription ?? "Unknown error")")
    }
    .resume()
     */
  }
}

struct Joke: Codable {
  let value: String
  
  static let empty = Joke(value: "")
}

public extension URLComponents {
  /// Maps a dictionary into `[URLQueryItem]` then assigns it to the
  /// `queryItems` property of this `URLComponents` instance.
  /// From [Alfian Losari's blog.](https://www.alfianlosari.com/posts/building-safe-url-in-swift-using-urlcomponents-and-urlqueryitem/)
  /// - Parameter parameters: Dictionary of query parameter names and values
  mutating func setQueryItems(with parameters: [String: String]) {
    self.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
  }
}
