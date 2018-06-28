/// Copyright (c) 2018 Razeware LLC
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
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

@testable import App
import Vapor
import XCTest
import FluentMySQL

final class AcronymTests : XCTestCase {

  let acronymsURI = "/api/acronyms/"
  let acronymShort = "OMG"
  let acronymLong = "Oh My God"
  var app: Application!
  var conn: MySQLConnection!

  override func setUp() {
    try! Application.reset()
    app = try! Application.testable()
    conn = try! app.newConnection(to: .mysql).wait()
  }

  override func tearDown() {
    conn.close()
  }

  func testAcronymsCanBeRetrievedFromAPI() throws {
    let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
    _ = try Acronym.create(on: conn)

    let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)

    XCTAssertEqual(acronyms.count, 2)
    XCTAssertEqual(acronyms[0].short, acronymShort)
    XCTAssertEqual(acronyms[0].long, acronymLong)
    XCTAssertEqual(acronyms[0].id, acronym1.id)
  }

  func testAcronymCanBeSavedWithAPI() throws {
    let user = try User.create(on: conn)
    let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
    let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)

    XCTAssertEqual(receivedAcronym.short, acronymShort)
    XCTAssertEqual(receivedAcronym.long, acronymLong)
    XCTAssertNotNil(receivedAcronym.id)

    let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)

    XCTAssertEqual(acronyms.count, 1)
    XCTAssertEqual(acronyms[0].short, acronymShort)
    XCTAssertEqual(acronyms[0].long, acronymLong)
    XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
  }

  func testGettingASingleAcronymFromTheAPI() throws {
    let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)

    let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)

    XCTAssertEqual(returnedAcronym.short, acronymShort)
    XCTAssertEqual(returnedAcronym.long, acronymLong)
    XCTAssertEqual(returnedAcronym.id, acronym.id)
  }

  func testUpdatingAnAcronym() throws {
    let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
    let newUser = try User.create(on: conn)
    let newLong = "Oh My Gosh"
    let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)

    try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)

    let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)

    XCTAssertEqual(returnedAcronym.short, acronymShort)
    XCTAssertEqual(returnedAcronym.long, newLong)
    XCTAssertEqual(returnedAcronym.userID, newUser.id)
  }

  func testDeletingAnAcronym() throws {
    let acronym = try Acronym.create(on: conn)
    var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)

    XCTAssertEqual(acronyms.count, 1)

    _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
    acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)

    XCTAssertEqual(acronyms.count, 0)
  }

  func testSearchAcronymShort() throws {
    let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
    let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)

    XCTAssertEqual(acronyms.count, 1)
    XCTAssertEqual(acronyms[0].id, acronym.id)
    XCTAssertEqual(acronyms[0].short, acronymShort)
    XCTAssertEqual(acronyms[0].long, acronymLong)
  }

  func testSearchAcronymLong() throws {
    let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
    let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)

    XCTAssertEqual(acronyms.count, 1)
    XCTAssertEqual(acronyms[0].id, acronym.id)
    XCTAssertEqual(acronyms[0].short, acronymShort)
    XCTAssertEqual(acronyms[0].long, acronymLong)
  }

  func testGetFirstAcronym() throws {
    let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
    _ = try Acronym.create(on: conn)
    _ = try Acronym.create(on: conn)

    let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)

    XCTAssertEqual(firstAcronym.id, acronym.id)
    XCTAssertEqual(firstAcronym.short, acronymShort)
    XCTAssertEqual(firstAcronym.long, acronymLong)
  }

  func testSortingAcronyms() throws {
    let short2 = "LOL"
    let long2 = "Laugh Out Loud"
    let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
    let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)

    let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)

    XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
    XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
  }

  func testGettingAnAcronymsUser() throws {
    let user = try User.create(on: conn)
    let acronym = try Acronym.create(user: user, on: conn)

    let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
    XCTAssertEqual(acronymsUser.id, user.id)
    XCTAssertEqual(acronymsUser.name, user.name)
    XCTAssertEqual(acronymsUser.username, user.username)
  }

  func testAcronymsCategories() throws {
    let category = try Category.create(on: conn)
    let category2 = try Category.create(name: "Funny", on: conn)
    let acronym = try Acronym.create(on: conn)

    _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
    _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)

    let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)

    XCTAssertEqual(categories.count, 2)
    XCTAssertEqual(categories[0].id, category.id)
    XCTAssertEqual(categories[0].name, category.name)
    XCTAssertEqual(categories[1].id, category2.id)
    XCTAssertEqual(categories[1].name, category2.name)
  }
    
    
    
    
    
    
    func testAcronymsCanBeRetrievedFromAPI2() throws {
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym1.id)
    }
    
    func testAcronymCanBeSavedWithAPI2() throws {
        let user = try User.create(on: conn)
        let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
        let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI2() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, acronymLong)
        XCTAssertEqual(returnedAcronym.id, acronym.id)
    }
    
    func testUpdatingAnAcronym2() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let newUser = try User.create(on: conn)
        let newLong = "Oh My Gosh"
        let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)
        
        try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, newLong)
        XCTAssertEqual(returnedAcronym.userID, newUser.id)
    }
    
    func testDeletingAnAcronym2() throws {
        let acronym = try Acronym.create(on: conn)
        var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
        acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testSearchAcronymShort2() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong2() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testGetFirstAcronym2() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSortingAcronyms2() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    func testGettingAnAcronymsUser2() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(user: user, on: conn)
        
        let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
        XCTAssertEqual(acronymsUser.id, user.id)
        XCTAssertEqual(acronymsUser.name, user.name)
        XCTAssertEqual(acronymsUser.username, user.username)
    }
    
    func testAcronymsCategories2() throws {
        let category = try Category.create(on: conn)
        let category2 = try Category.create(name: "Funny", on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
        
        let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category.id)
        XCTAssertEqual(categories[0].name, category.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2.name)
    }
    
    
    

    func testAcronymsCanBeRetrievedFromAPI3() throws {
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym1.id)
    }
    
    func testAcronymCanBeSavedWithAPI3() throws {
        let user = try User.create(on: conn)
        let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
        let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI3() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, acronymLong)
        XCTAssertEqual(returnedAcronym.id, acronym.id)
    }
    
    func testUpdatingAnAcronym3() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let newUser = try User.create(on: conn)
        let newLong = "Oh My Gosh"
        let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)
        
        try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, newLong)
        XCTAssertEqual(returnedAcronym.userID, newUser.id)
    }
    
    func testDeletingAnAcronym3() throws {
        let acronym = try Acronym.create(on: conn)
        var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
        acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testSearchAcronymShort3() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong3() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testGetFirstAcronym3() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSortingAcronyms3() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    func testGettingAnAcronymsUser3() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(user: user, on: conn)
        
        let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
        XCTAssertEqual(acronymsUser.id, user.id)
        XCTAssertEqual(acronymsUser.name, user.name)
        XCTAssertEqual(acronymsUser.username, user.username)
    }
    
    func testAcronymsCategories3() throws {
        let category = try Category.create(on: conn)
        let category2 = try Category.create(name: "Funny", on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
        
        let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category.id)
        XCTAssertEqual(categories[0].name, category.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2.name)
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    func testAcronymsCanBeRetrievedFromAPI34() throws {
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym1.id)
    }
    
    func testAcronymCanBeSavedWithAPI34() throws {
        let user = try User.create(on: conn)
        let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
        let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI34() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, acronymLong)
        XCTAssertEqual(returnedAcronym.id, acronym.id)
    }
    
    func testUpdatingAnAcronym34() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let newUser = try User.create(on: conn)
        let newLong = "Oh My Gosh"
        let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)
        
        try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, newLong)
        XCTAssertEqual(returnedAcronym.userID, newUser.id)
    }
    
    func testDeletingAnAcronym34() throws {
        let acronym = try Acronym.create(on: conn)
        var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
        acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testSearchAcronymShort34() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong34() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testGetFirstAcronym34() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSortingAcronyms34() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    func testGettingAnAcronymsUser34() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(user: user, on: conn)
        
        let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
        XCTAssertEqual(acronymsUser.id, user.id)
        XCTAssertEqual(acronymsUser.name, user.name)
        XCTAssertEqual(acronymsUser.username, user.username)
    }
    
    func testAcronymsCategories34() throws {
        let category = try Category.create(on: conn)
        let category2 = try Category.create(name: "Funny", on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
        
        let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category.id)
        XCTAssertEqual(categories[0].name, category.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2.name)
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    func testAcronymsCanBeRetrievedFromAPI35() throws {
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym1.id)
    }
    
    func testAcronymCanBeSavedWithAPI35() throws {
        let user = try User.create(on: conn)
        let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
        let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI35() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, acronymLong)
        XCTAssertEqual(returnedAcronym.id, acronym.id)
    }
    
    func testUpdatingAnAcronym35() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let newUser = try User.create(on: conn)
        let newLong = "Oh My Gosh"
        let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)
        
        try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, newLong)
        XCTAssertEqual(returnedAcronym.userID, newUser.id)
    }
    
    func testDeletingAnAcronym35() throws {
        let acronym = try Acronym.create(on: conn)
        var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
        acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testSearchAcronymShort35() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong35() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testGetFirstAcronym35() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSortingAcronyms35() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    func testGettingAnAcronymsUser35() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(user: user, on: conn)
        
        let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
        XCTAssertEqual(acronymsUser.id, user.id)
        XCTAssertEqual(acronymsUser.name, user.name)
        XCTAssertEqual(acronymsUser.username, user.username)
    }
    
    func testAcronymsCategories35() throws {
        let category = try Category.create(on: conn)
        let category2 = try Category.create(name: "Funny", on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
        
        let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category.id)
        XCTAssertEqual(categories[0].name, category.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2.name)
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    func testAcronymsCanBeRetrievedFromAPI36() throws {
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym1.id)
    }
    
    func testAcronymCanBeSavedWithAPI36() throws {
        let user = try User.create(on: conn)
        let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
        let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI36() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, acronymLong)
        XCTAssertEqual(returnedAcronym.id, acronym.id)
    }
    
    func testUpdatingAnAcronym36() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let newUser = try User.create(on: conn)
        let newLong = "Oh My Gosh"
        let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)
        
        try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, newLong)
        XCTAssertEqual(returnedAcronym.userID, newUser.id)
    }
    
    func testDeletingAnAcronym36() throws {
        let acronym = try Acronym.create(on: conn)
        var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
        acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testSearchAcronymShort36() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong36() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testGetFirstAcronym36() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSortingAcronyms36() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    func testGettingAnAcronymsUser36() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(user: user, on: conn)
        
        let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
        XCTAssertEqual(acronymsUser.id, user.id)
        XCTAssertEqual(acronymsUser.name, user.name)
        XCTAssertEqual(acronymsUser.username, user.username)
    }
    
    func testAcronymsCategories36() throws {
        let category = try Category.create(on: conn)
        let category2 = try Category.create(name: "Funny", on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
        
        let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category.id)
        XCTAssertEqual(categories[0].name, category.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2.name)
    }
    
    

    
    
    
    
    
    
    func testAcronymsCanBeRetrievedFromAPI361() throws {
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym1.id)
    }
    
    func testAcronymCanBeSavedWithAPI361() throws {
        let user = try User.create(on: conn)
        let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
        let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI361() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, acronymLong)
        XCTAssertEqual(returnedAcronym.id, acronym.id)
    }
    
    func testUpdatingAnAcronym361() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let newUser = try User.create(on: conn)
        let newLong = "Oh My Gosh"
        let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)
        
        try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, newLong)
        XCTAssertEqual(returnedAcronym.userID, newUser.id)
    }
    
    func testDeletingAnAcronym361() throws {
        let acronym = try Acronym.create(on: conn)
        var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
        acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testSearchAcronymShort361() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong361() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testGetFirstAcronym361() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSortingAcronyms361() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    func testGettingAnAcronymsUser361() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(user: user, on: conn)
        
        let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
        XCTAssertEqual(acronymsUser.id, user.id)
        XCTAssertEqual(acronymsUser.name, user.name)
        XCTAssertEqual(acronymsUser.username, user.username)
    }
    
    func testAcronymsCategories361() throws {
        let category = try Category.create(on: conn)
        let category2 = try Category.create(name: "Funny", on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
        
        let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category.id)
        XCTAssertEqual(categories[0].name, category.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2.name)
    }
    
    
    
    
    
    
    
    
    
    
    
    func testAcronymsCanBeRetrievedFromAPI362() throws {
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym1.id)
    }
    
    func testAcronymCanBeSavedWithAPI362() throws {
        let user = try User.create(on: conn)
        let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
        let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI362() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, acronymLong)
        XCTAssertEqual(returnedAcronym.id, acronym.id)
    }
    
    func testUpdatingAnAcronym362() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let newUser = try User.create(on: conn)
        let newLong = "Oh My Gosh"
        let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)
        
        try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, newLong)
        XCTAssertEqual(returnedAcronym.userID, newUser.id)
    }
    
    func testDeletingAnAcronym362() throws {
        let acronym = try Acronym.create(on: conn)
        var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
        acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testSearchAcronymShort362() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong362() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testGetFirstAcronym362() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSortingAcronyms362() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    func testGettingAnAcronymsUser362() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(user: user, on: conn)
        
        let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
        XCTAssertEqual(acronymsUser.id, user.id)
        XCTAssertEqual(acronymsUser.name, user.name)
        XCTAssertEqual(acronymsUser.username, user.username)
    }
    
    func testAcronymsCategories362() throws {
        let category = try Category.create(on: conn)
        let category2 = try Category.create(name: "Funny", on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
        
        let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category.id)
        XCTAssertEqual(categories[0].name, category.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2.name)
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    func testAcronymsCanBeRetrievedFromAPI363() throws {
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym1.id)
    }
    
    func testAcronymCanBeSavedWithAPI363() throws {
        let user = try User.create(on: conn)
        let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
        let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI363() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, acronymLong)
        XCTAssertEqual(returnedAcronym.id, acronym.id)
    }
    
    func testUpdatingAnAcronym363() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let newUser = try User.create(on: conn)
        let newLong = "Oh My Gosh"
        let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)
        
        try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, newLong)
        XCTAssertEqual(returnedAcronym.userID, newUser.id)
    }
    
    func testDeletingAnAcronym363() throws {
        let acronym = try Acronym.create(on: conn)
        var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
        acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testSearchAcronymShort363() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong363() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testGetFirstAcronym363() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSortingAcronyms363() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    func testGettingAnAcronymsUser363() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(user: user, on: conn)
        
        let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
        XCTAssertEqual(acronymsUser.id, user.id)
        XCTAssertEqual(acronymsUser.name, user.name)
        XCTAssertEqual(acronymsUser.username, user.username)
    }
    
    func testAcronymsCategories363() throws {
        let category = try Category.create(on: conn)
        let category2 = try Category.create(name: "Funny", on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
        
        let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category.id)
        XCTAssertEqual(categories[0].name, category.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2.name)
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    func testAcronymsCanBeRetrievedFromAPI364() throws {
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym1.id)
    }
    
    func testAcronymCanBeSavedWithAPI364() throws {
        let user = try User.create(on: conn)
        let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
        let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI364() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, acronymLong)
        XCTAssertEqual(returnedAcronym.id, acronym.id)
    }
    
    func testUpdatingAnAcronym364() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let newUser = try User.create(on: conn)
        let newLong = "Oh My Gosh"
        let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)
        
        try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, newLong)
        XCTAssertEqual(returnedAcronym.userID, newUser.id)
    }
    
    func testDeletingAnAcronym364() throws {
        let acronym = try Acronym.create(on: conn)
        var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
        acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testSearchAcronymShort364() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong364() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testGetFirstAcronym364() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSortingAcronyms364() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    func testGettingAnAcronymsUser364() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(user: user, on: conn)
        
        let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
        XCTAssertEqual(acronymsUser.id, user.id)
        XCTAssertEqual(acronymsUser.name, user.name)
        XCTAssertEqual(acronymsUser.username, user.username)
    }
    
    func testAcronymsCategories364() throws {
        let category = try Category.create(on: conn)
        let category2 = try Category.create(name: "Funny", on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
        
        let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category.id)
        XCTAssertEqual(categories[0].name, category.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2.name)
    }
    
    
    
    
    
    
    
    
    
    
    func testAcronymsCanBeRetrievedFromAPI3641() throws {
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym1.id)
    }
    
    func testAcronymCanBeSavedWithAPI3641() throws {
        let user = try User.create(on: conn)
        let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
        let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI3641() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, acronymLong)
        XCTAssertEqual(returnedAcronym.id, acronym.id)
    }
    
    func testUpdatingAnAcronym3641() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let newUser = try User.create(on: conn)
        let newLong = "Oh My Gosh"
        let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)
        
        try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, newLong)
        XCTAssertEqual(returnedAcronym.userID, newUser.id)
    }
    
    func testDeletingAnAcronym3641() throws {
        let acronym = try Acronym.create(on: conn)
        var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
        acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testSearchAcronymShort3641() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong3641() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testGetFirstAcronym3641() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSortingAcronyms3641() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    func testGettingAnAcronymsUser3641() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(user: user, on: conn)
        
        let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
        XCTAssertEqual(acronymsUser.id, user.id)
        XCTAssertEqual(acronymsUser.name, user.name)
        XCTAssertEqual(acronymsUser.username, user.username)
    }
    
    func testAcronymsCategories3641() throws {
        let category = try Category.create(on: conn)
        let category2 = try Category.create(name: "Funny", on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
        
        let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category.id)
        XCTAssertEqual(categories[0].name, category.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2.name)
    }
    
    
    
    
    
    
    
    
    
    func testAcronymsCanBeRetrievedFromAPI3642() throws {
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym1.id)
    }
    
    func testAcronymCanBeSavedWithAPI3642() throws {
        let user = try User.create(on: conn)
        let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
        let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI3642() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, acronymLong)
        XCTAssertEqual(returnedAcronym.id, acronym.id)
    }
    
    func testUpdatingAnAcronym3642() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let newUser = try User.create(on: conn)
        let newLong = "Oh My Gosh"
        let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)
        
        try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, newLong)
        XCTAssertEqual(returnedAcronym.userID, newUser.id)
    }
    
    func testDeletingAnAcronym3642() throws {
        let acronym = try Acronym.create(on: conn)
        var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
        acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testSearchAcronymShort3642() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong3642() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testGetFirstAcronym3642() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSortingAcronyms3642() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    func testGettingAnAcronymsUser3642() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(user: user, on: conn)
        
        let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
        XCTAssertEqual(acronymsUser.id, user.id)
        XCTAssertEqual(acronymsUser.name, user.name)
        XCTAssertEqual(acronymsUser.username, user.username)
    }
    
    func testAcronymsCategories3642() throws {
        let category = try Category.create(on: conn)
        let category2 = try Category.create(name: "Funny", on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
        
        let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category.id)
        XCTAssertEqual(categories[0].name, category.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2.name)
    }
    
    
    
    
    
    
    
    
    
    
    func testAcronymsCanBeRetrievedFromAPI3643() throws {
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym1.id)
    }
    
    func testAcronymCanBeSavedWithAPI3643() throws {
        let user = try User.create(on: conn)
        let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
        let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI3643() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, acronymLong)
        XCTAssertEqual(returnedAcronym.id, acronym.id)
    }
    
    func testUpdatingAnAcronym3643() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let newUser = try User.create(on: conn)
        let newLong = "Oh My Gosh"
        let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)
        
        try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, newLong)
        XCTAssertEqual(returnedAcronym.userID, newUser.id)
    }
    
    func testDeletingAnAcronym3643() throws {
        let acronym = try Acronym.create(on: conn)
        var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
        acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testSearchAcronymShort3643() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong3643() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testGetFirstAcronym3643() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSortingAcronyms3643() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    func testGettingAnAcronymsUser3643() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(user: user, on: conn)
        
        let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
        XCTAssertEqual(acronymsUser.id, user.id)
        XCTAssertEqual(acronymsUser.name, user.name)
        XCTAssertEqual(acronymsUser.username, user.username)
    }
    
    func testAcronymsCategories3643() throws {
        let category = try Category.create(on: conn)
        let category2 = try Category.create(name: "Funny", on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
        
        let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category.id)
        XCTAssertEqual(categories[0].name, category.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2.name)
    }
    
    
    
    
    
    
    
    
    
    func testAcronymsCanBeRetrievedFromAPI3644() throws {
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym1.id)
    }
    
    func testAcronymCanBeSavedWithAPI3644() throws {
        let user = try User.create(on: conn)
        let acronym = Acronym(short: acronymShort, long: acronymLong, userID: user.id!)
        let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
        
        let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI3644() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, acronymLong)
        XCTAssertEqual(returnedAcronym.id, acronym.id)
    }
    
    func testUpdatingAnAcronym3644() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let newUser = try User.create(on: conn)
        let newLong = "Oh My Gosh"
        let updatedAcronym = Acronym(short: acronymShort, long: newLong, userID: newUser.id!)
        
        try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
        
        let returnedAcronym = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)", decodeTo: Acronym.self)
        
        XCTAssertEqual(returnedAcronym.short, acronymShort)
        XCTAssertEqual(returnedAcronym.long, newLong)
        XCTAssertEqual(returnedAcronym.userID, newUser.id)
    }
    
    func testDeletingAnAcronym3644() throws {
        let acronym = try Acronym.create(on: conn)
        var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)", method: .DELETE, loggedInRequest: true)
        acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testSearchAcronymShort3644() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong3644() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testGetFirstAcronym3644() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(to: "\(acronymsURI)first", decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSortingAcronyms3644() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    func testGettingAnAcronymsUser3644() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(user: user, on: conn)
        
        let acronymsUser = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/user", decodeTo: User.Public.self)
        XCTAssertEqual(acronymsUser.id, user.id)
        XCTAssertEqual(acronymsUser.name, user.name)
        XCTAssertEqual(acronymsUser.username, user.username)
    }
    
    func testAcronymsCategories3644() throws {
        let category = try Category.create(on: conn)
        let category2 = try Category.create(name: "Funny", on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
        _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
        
        let categories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category.id)
        XCTAssertEqual(categories[0].name, category.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2.name)
    }
    
  static let allTests = [
    ("testAcronymsCanBeRetrievedFromAPI", testAcronymsCanBeRetrievedFromAPI),
    ("testAcronymCanBeSavedWithAPI", testAcronymCanBeSavedWithAPI),
    ("testGettingASingleAcronymFromTheAPI", testGettingASingleAcronymFromTheAPI),
    ("testUpdatingAnAcronym", testUpdatingAnAcronym),
    ("testDeletingAnAcronym", testDeletingAnAcronym),
    ("testSearchAcronymShort", testSearchAcronymShort),
    ("testSearchAcronymLong", testSearchAcronymLong),
    ("testGetFirstAcronym", testGetFirstAcronym),
    ("testSortingAcronyms", testSortingAcronyms),
    ("testGettingAnAcronymsUser", testGettingAnAcronymsUser),
    ("testAcronymsCategories", testAcronymsCategories),
    ]
}
