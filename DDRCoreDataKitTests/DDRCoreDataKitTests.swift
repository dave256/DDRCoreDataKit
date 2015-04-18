//
//  DDRCoreDataKitTests.swift
//  DDRCoreDataKitTests
//
//  Created by David Reed on 6/13/14.
//  Copyright (c) 2014 David Reed. All rights reserved.
//

import XCTest
import CoreData
import DDRCoreDataKit

func checkSaveError(status: DDROkOrError, shouldBeOk: Bool = true) {

    var ok: Bool = true
    switch status {
    case .Ok:
        if !shouldBeOk {
            XCTFail("save worked when it should have failed")
        }
    case .Error(let error):
        if (shouldBeOk) {
            XCTFail("save failed: \(error.localizedDescription) \(error.userInfo)")
        }
    case .ErrorString(let s):
        if (shouldBeOk) {
            XCTFail("save failed: \(s)")
        }
    }
}

class DDRCoreDataKitTests: XCTestCase {

    var storeURL : NSURL? = nil
    var doc : DDRCoreDataDocument! = nil

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        storeURL = NSURL(fileURLWithPath: NSTemporaryDirectory().stringByAppendingPathComponent("test.sqlite"))
        let modelURL = NSBundle(forClass: DDRCoreDataKitTests.self).URLForResource("DDRCoreDataKitTests", withExtension: "momd")!
        doc = DDRCoreDataDocument(storeURL: storeURL, modelURL: modelURL, options: nil)
        XCTAssertNotNil(doc, "doc is nil when it should not be")
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        NSFileManager().removeItemAtURL(storeURL!, error: nil)
    }

    /*
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }
*/

    func testCoreDateDocumentError() {
        let badURL = NSURL(fileURLWithPath: "/no-directory/file.sql")
        let modelURL = NSBundle(forClass: DDRCoreDataKitTests.self).URLForResource("DDRCoreDataKitTests", withExtension: "momd")!
        doc = DDRCoreDataDocument(storeURL: badURL, modelURL: modelURL, options: nil)
        XCTAssertNil(doc, "doc is not nil for a bad URL")
    }

    func testSaveError() {
        let moc = doc.mainQueueMOC
        insertDaveReedInManagedObjectContext(moc)

        var error: NSError? = nil
        NSFileManager.defaultManager().removeItemAtURL(storeURL!, error: &error)
        XCTAssertNil(error, "failed to delete file: \(error?.localizedDescription) \(error?.userInfo)")
        let status = doc.saveContextAndWait(true)
        checkSaveError(status, shouldBeOk: false)
    }

    func testInsertionOfPersonObjects() {
        let moc = doc.mainQueueMOC

        if moc != nil {
            insertDaveReedInManagedObjectContext(moc)
            insertDaveSmithInManagedObjectContext(moc)
            insertJohnStroehInManagedObjectContext(moc)

            var sorters = [NSSortDescriptor(key: "lastName", ascending: true), NSSortDescriptor(key: "firstName", ascending: true)]
            var predicate = NSPredicate(format: "%K=%@", "firstName", "Dave")
            var items = Person.allInstancesWithPredicate(predicate, sortDescriptors: sorters, inManagedObjectContext: moc)
            XCTAssertEqual(items.count, 2, "items.count is not 2")
            var p : Person
            p = items[0] as! Person
            assertDaveReed(p)
            p = items[1] as! Person
            assertDaveSmith(p)

            let status = doc.saveContextAndWait(true)
            checkSaveError(status)

        } else {
            XCTFail("mainMOC is nil")
        }
    }

    func testChildManagedObjectContext() {
        let moc = doc.mainQueueMOC

        if moc != nil {
            let childMOC = doc.newChildOfMainObjectContextWithConcurrencyType(NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
            insertDaveReedInManagedObjectContext(moc)
            insertDaveSmithInManagedObjectContext(moc)
            childMOC.performBlockAndWait() {
                self.insertJohnStroehInManagedObjectContext(childMOC)
            }
            var sorters = [NSSortDescriptor(key: "lastName", ascending: true), NSSortDescriptor(key: "firstName", ascending: true)]
            var items = Person.allInstancesWithPredicate(nil, sortDescriptors: sorters, inManagedObjectContext: moc)
            XCTAssertEqual(items.count, 2, "items.count is not 2")

            var p : Person
            p = items[0] as! Person
            assertDaveReed(p)
            p = items[1] as! Person
            assertDaveSmith(p)

            childMOC.performBlockAndWait() {
                items = Person.allInstancesWithPredicate(nil, sortDescriptors: sorters, inManagedObjectContext: childMOC)
            }
            // childMOC should have 3 items
            XCTAssertEqual(items.count, 3, "items.count is not 3")
            p = items[2] as! Person
            assertJohnStroeh(p)

            // mainMOC should still have 2 items
            items = Person.allInstancesWithPredicate(nil, sortDescriptors: sorters, inManagedObjectContext: moc)
            XCTAssertEqual(items.count, 2, "items.count is not 2")

            childMOC.performBlockAndWait() {
                var error : NSError? = nil
                childMOC.save(&error)
                XCTAssertNil(error, "childMOC save error not nil: \(error?.localizedDescription) \(error?.userInfo)")
            }

            // now mainMOC should have 3 items
            items = Person.allInstancesWithPredicate(nil, sortDescriptors: sorters, inManagedObjectContext: moc)
            // childMOC should have 3 items
            XCTAssertEqual(items.count, 3, "items.count is not 3")
            p = items[2] as! Person
            assertJohnStroeh(p)

            var error : NSError?
            let status = doc!.saveContextAndWait(true)
            checkSaveError(status)
        } else {
            XCTFail("mainMOC is nil")
        }
    }

    func testSyncedPerson() {
        let moc = doc.mainQueueMOC

        if moc != nil {
            var p = SyncedPerson(managedObjectContext: moc)
            p.firstName = "Dave"
            p.lastName = "Reed"
            XCTAssertNotNil(p.ddrSyncIdentifier, "ddrSyncIdentifier is not nil")
        }
    }

    // MARK: - helper methods

    func insertPersonWithFirstName(firstName: String, lastName: String, inManagedObjectContext moc: NSManagedObjectContext) {
        //var p = Person.newInstanceInManagedObjectContext(moc) as Person
        var p = Person(managedObjectContext: moc)
        p.firstName = firstName
        p.lastName = lastName
    }

    func insertDaveReedInManagedObjectContext(moc: NSManagedObjectContext) {
        insertPersonWithFirstName("Dave", lastName: "Reed", inManagedObjectContext: moc)
    }

    func insertDaveSmithInManagedObjectContext(moc: NSManagedObjectContext) {
        insertPersonWithFirstName("Dave", lastName: "Smith", inManagedObjectContext: moc)
    }

    func insertJohnStroehInManagedObjectContext(moc: NSManagedObjectContext) {
        insertPersonWithFirstName("John", lastName: "Stroeh", inManagedObjectContext: moc)
    }

    func assertPerson(person : Person, hasFirstName firstName: String, lastName: String) {
        XCTAssertEqual(person.firstName!, firstName, "first name is not \(firstName)")
        XCTAssertEqual(person.lastName!, lastName, "first name is not \(lastName)")
    }

    func assertDaveReed(person: Person) {
        assertPerson(person, hasFirstName: "Dave", lastName: "Reed")
    }

    func assertDaveSmith(person: Person) {
        assertPerson(person, hasFirstName: "Dave", lastName: "Smith")
    }

    func assertJohnStroeh(person: Person) {
        assertPerson(person, hasFirstName: "John", lastName: "Stroeh")
    }

}
