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
        NSFileManager().removeItemAtURL(storeURL!, error: nil)
        let modelURL = NSBundle(forClass: DDRCoreDataKitTests.self).URLForResource("DDRCoreDataKitTests", withExtension: "momd")!
        doc = DDRCoreDataDocument(storeURL: storeURL, modelURL: modelURL, options: nil)
        XCTAssertNotNil(doc, "doc is nil when it should not be")
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        NSFileManager().removeItemAtURL(storeURL!, error: nil)
    }

    func testOpeningUIManagedDocumentDirectory() {
        let storeURL = NSURL(fileURLWithPath: NSTemporaryDirectory().stringByAppendingPathComponent("test.sqlite3"))
        let modelURL = NSBundle(forClass: DDRCoreDataKitTests.self).URLForResource("DDRCoreDataKitTests", withExtension: "momd")!
        let tempDoc = DDRCoreDataDocument(storeURL: storeURL, modelURL: modelURL, options: nil)
        XCTAssertNotNil(tempDoc, "doc is nil when it should not be")
        let moc = tempDoc?.mainQueueMOC
        let p = Person(managedObjectContext: moc)
        p.firstName = "Dave"
        p.lastName = "Reed"
        tempDoc?.saveContextAndWait(true)

        let dfm = NSFileManager.defaultManager()
        let path = NSTemporaryDirectory().stringByAppendingPathComponent("CS161").stringByAppendingPathComponent("StoreContent")

        dfm.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil, error: nil)
        let destinationURL = NSURL(fileURLWithPath: path.stringByAppendingPathComponent("persistentStore"))
        XCTAssertNotNil(destinationURL!, "destinationURL is not nil")
        dfm.removeItemAtURL(destinationURL!, error: nil)
        var error: NSError? = nil
        dfm.moveItemAtURL(storeURL!, toURL: destinationURL!, error: &error)
        XCTAssertNil(error, "move item error not nil")

        let docURL = NSURL(fileURLWithPath: NSTemporaryDirectory().stringByAppendingPathComponent("CS161"))
        XCTAssertNotNil(docURL, "docURL is not nil")
        let localDoc = DDRCoreDataDocument(storeURL: docURL, modelURL: modelURL, options: nil)
        XCTAssertNotNil(localDoc, "doc is nil when it should not be")
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
            let childMOC = doc.newChildOfMainObjectContextWithConcurrencyType(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
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
                // childMOC should have 3 items
                XCTAssertEqual(items.count, 3, "items.count is not 3")
                p = items[2] as! Person
                self.assertJohnStroeh(p)
            }

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

    func testSameManagedObjectWithSameMOC() {
        let moc = doc.mainQueueMOC
        XCTAssertNotNil(moc, "mainQueueMOC is nil")
        let p1 = insertDaveReedInManagedObjectContext(moc)
        var error: NSError? = nil
        //moc.obtainPermanentIDsForObjects([p1], error: &error)
        XCTAssertNil(error, "obtainPerfmanentIDsForObjects had non nil error")

        let otherMoc = doc.mainQueueMOC //doc.newChildOfMainObjectContextWithConcurrencyType(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        let p2 = p1.sameManagedObjectUsingManagedObjectContext(managedObjectContext: otherMoc) as! Person?
        XCTAssertNotNil(p2, "person in other MOC is nil")
        assertPerson(p2!, hasFirstName: "Dave", lastName: "Reed")
        let objectID = p1.objectID
        otherMoc.performBlockAndWait { () -> Void in
            XCTAssertEqual(objectID, p2!.objectID, "objectIDs do not match")
        }
    }

    func testSameManagedObjectWithAnotherMainQueueMOC() {
        let moc = doc.mainQueueMOC
        XCTAssertNotNil(moc, "mainQueueMOC is nil")
        let p1 = insertDaveReedInManagedObjectContext(moc)
        var error: NSError? = nil
        //moc.obtainPermanentIDsForObjects([p1], error: &error)
        XCTAssertNil(error, "obtainPerfmanentIDsForObjects had non nil error")

        let otherMoc = doc.newChildOfMainObjectContextWithConcurrencyType(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        let p2 = p1.sameManagedObjectUsingManagedObjectContext(managedObjectContext: otherMoc) as! Person?
        let objectID = p1.objectID
        otherMoc.performBlockAndWait {
            XCTAssertNotNil(p2, "person in other MOC is nil")
            self.assertPerson(p2!, hasFirstName: "Dave", lastName: "Reed")
            XCTAssertEqual(objectID, p2!.objectID, "objectIDs do not match")
        }
    }

    func testSameManagedObjectWithPrivateChildMOC() {
        let moc = doc.mainQueueMOC
        XCTAssertNotNil(moc, "mainQueueMOC is nil")
        let p1 = insertDaveReedInManagedObjectContext(moc)
        var error: NSError? = nil
        //moc.obtainPermanentIDsForObjects([p1], error: &error)
        XCTAssertNil(error, "obtainPerfmanentIDsForObjects had non nil error")

        let otherMoc = doc.newChildOfMainObjectContextWithConcurrencyType()
        let p2 = p1.sameManagedObjectUsingManagedObjectContext(managedObjectContext: otherMoc) as! Person?
        otherMoc.performBlockAndWait {
            XCTAssertNotNil(p2, "person in other MOC is nil")
            self.assertPerson(p2!, hasFirstName: "Dave", lastName: "Reed")
        }
        let objectID = p1.objectID
        otherMoc.performBlockAndWait {
            XCTAssertNotNil(p2, "person in other MOC is nil")
            self.assertPerson(p2!, hasFirstName: "Dave", lastName: "Reed")
            XCTAssertEqual(objectID, p2!.objectID, "objectIDs do not match")
        }
        // if fail to use performBlock, this will crash if set -com.apple.CoreData.ConcurrencyDebug 1
        // as arguments passed on launch in Scheme, Run section
        // self.assertPerson(p2!, hasFirstName: "Dave", lastName: "Reed")
    }



    // MARK: - helper methods

    func insertPersonWithFirstName(firstName: String, lastName: String, inManagedObjectContext moc: NSManagedObjectContext) -> Person {
        //var p = Person.newInstanceInManagedObjectContext(moc) as Person
        var p = Person(managedObjectContext: moc)
        p.firstName = firstName
        p.lastName = lastName
        return p
    }

    func insertDaveReedInManagedObjectContext(moc: NSManagedObjectContext) -> Person {
        return insertPersonWithFirstName("Dave", lastName: "Reed", inManagedObjectContext: moc)
    }

    func insertDaveSmithInManagedObjectContext(moc: NSManagedObjectContext) -> Person {
        return insertPersonWithFirstName("Dave", lastName: "Smith", inManagedObjectContext: moc)
    }

    func insertJohnStroehInManagedObjectContext(moc: NSManagedObjectContext) -> Person {
        return insertPersonWithFirstName("John", lastName: "Stroeh", inManagedObjectContext: moc)
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
