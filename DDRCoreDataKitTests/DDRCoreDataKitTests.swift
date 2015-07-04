//
//  DDRCoreDataKitTests.swift
//  DDRCoreDataKitTests
//
//  Created by David Reed on 6/19/15.
//  Copyright © 2015 David Reed. All rights reserved.
//


import XCTest
import CoreData
import DDRCoreDataKit


func checkSaveError(status: DDRCoreDataSaveOrError, shouldBeOk: Bool = true, checkHadChanges: Bool = false, shouldHaveChanges: Bool = true) {

    switch status {
    case .SaveOkHadChanges(let hadChanges):
        if !shouldBeOk {
            XCTFail("save worked when it should have failed")
        }
        if checkHadChanges {
            XCTAssertEqual(hadChanges, shouldHaveChanges)
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
        do {
            try NSFileManager().removeItemAtURL(storeURL!)
        } catch _ {
        }
        let modelURL = NSBundle(forClass: DDRCoreDataKitTests.self).URLForResource("DDRCoreDataKitTests", withExtension: "momd")!
        doc = DDRCoreDataDocument(storeURL: storeURL, modelURL: modelURL, options: nil)
        XCTAssertNotNil(doc, "doc is nil when it should not be")
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        do {
            try NSFileManager().removeItemAtURL(storeURL!)
        } catch _ {
        }
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

        do {
            try dfm.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
        } catch _ {
        }
        let destinationURL = NSURL(fileURLWithPath: path.stringByAppendingPathComponent("persistentStore"))
        XCTAssertNotNil(destinationURL, "destinationURL is not nil")
        do {
            try dfm.removeItemAtURL(destinationURL)
        } catch _ {
        }
        var error: NSError? = nil
        do {
            try dfm.moveItemAtURL(storeURL, toURL: destinationURL)
        } catch let error1 as NSError {
            error = error1
        }
        XCTAssertNil(error, "move item error not nil")

        let docURL = NSURL(fileURLWithPath: NSTemporaryDirectory().stringByAppendingPathComponent("CS161"))
        XCTAssertNotNil(docURL, "docURL is not nil")
        let localDoc = DDRCoreDataDocument(storeURL: docURL, modelURL: modelURL, options: nil)
        XCTAssertNotNil(localDoc, "doc is nil when it should not be")
    }



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
        do {
            try NSFileManager.defaultManager().removeItemAtURL(storeURL!)
        } catch let error1 as NSError {
            error = error1
        }
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

            let sorters = [NSSortDescriptor(key: "lastName", ascending: true), NSSortDescriptor(key: "firstName", ascending: true)]
            let predicate = NSPredicate(format: "%K=%@", "firstName", "Dave")
            var items = try! Person.instancesInManagedObjectContext(moc, withPredicate: predicate, sortedBy: sorters)
            XCTAssertEqual(items.count, 2, "items.count is not 2")
            var p : Person
            p = items[0] as! Person
            assertDaveReed(p)
            p = items[1] as! Person
            assertDaveSmith(p)

            let status = doc.saveContextAndWait(true)
            checkSaveError(status, shouldBeOk: true, checkHadChanges: true, shouldHaveChanges: true)
            let status2 = doc.saveContextAndWait(true)
            checkSaveError(status2, shouldBeOk: true, checkHadChanges: true, shouldHaveChanges: false)

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
            let sorters = [NSSortDescriptor(key: "lastName", ascending: true), NSSortDescriptor(key: "firstName", ascending: true)]
            var items = try! Person.allInstancesInManagedObjectContext(moc, sortedBy: sorters)
            XCTAssertEqual(items.count, 2, "items.count is not 2")

            var p : Person
            p = items[0] as! Person
            assertDaveReed(p)
            p = items[1] as! Person
            assertDaveSmith(p)

            childMOC.performBlockAndWait() { [unowned self] in
                items = try! Person.allInstancesInManagedObjectContext(childMOC, sortedBy: sorters)

                // childMOC should have 3 items
                XCTAssertEqual(items.count, 3, "items.count is not 3")
                p = items[2] as! Person
                self.assertJohnStroeh(p)
            }

            // mainMOC should still have 2 items
            items = try! Person.allInstancesInManagedObjectContext(moc, sortedBy: sorters)
            XCTAssertEqual(items.count, 2, "items.count is not 2")

            childMOC.performBlockAndWait() {
                var error : NSError? = nil
                do {
                    try childMOC.save()
                } catch let error1 as NSError {
                    error = error1
                } catch {
                    fatalError()
                }
                XCTAssertNil(error, "childMOC save error not nil: \(error?.localizedDescription) \(error?.userInfo)")
            }

            // now mainMOC should have 3 items
            items = try! Person.allInstancesInManagedObjectContext(moc, sortedBy: sorters)
            // childMOC should have 3 items
            XCTAssertEqual(items.count, 3, "items.count is not 3")
            p = items[2] as! Person
            assertJohnStroeh(p)

            let status = doc!.saveContextAndWait(true)
            checkSaveError(status)
        } else {
            XCTFail("mainMOC is nil")
        }
    }

    /*
    func testSyncedPerson() {
        let moc = doc.mainQueueMOC

        if moc != nil {
            let p = SyncedPerson(managedObjectContext: moc)
            p.firstName = "Dave"
            p.lastName = "Reed"
            XCTAssertNotNil(p.ddrSyncIdentifier, "ddrSyncIdentifier is not nil")
        }
    }
*/

    func testSameManagedObjectWithSameMOC() {
        let moc = doc.mainQueueMOC
        insertDaveReedInManagedObjectContext(moc)
        doc.saveContextAndWait(true)
        let p1 = try! Person.allInstancesInManagedObjectContext(moc)[0] as! Person
        XCTAssertNotNil(moc, "mainQueueMOC is nil")

        let otherMoc = doc.newChildOfMainObjectContextWithConcurrencyType(NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
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
        insertDaveReedInManagedObjectContext(moc)
        doc.saveContextAndWait(true)
        let p1 = try! Person.allInstancesInManagedObjectContext(moc)[0] as! Person
        XCTAssertNotNil(moc, "mainQueueMOC is nil")
        let otherMoc = doc.newChildOfMainObjectContextWithConcurrencyType(NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        let p2 = p1.sameManagedObjectUsingManagedObjectContext(managedObjectContext: otherMoc) as! Person?
        let objectID = p1.objectID
        otherMoc.performBlockAndWait { [unowned self] in
            XCTAssertNotNil(p2, "person in other MOC is nil")
            self.assertPerson(p2!, hasFirstName: "Dave", lastName: "Reed")
            XCTAssertEqual(objectID, p2!.objectID, "objectIDs do not match")
        }
    }

    func testSameManagedObjectWithPrivateChildMOC() {
        let moc = doc.mainQueueMOC
        insertDaveReedInManagedObjectContext(moc)
        doc.saveContextAndWait(true)
        let p1 = try! Person.allInstancesInManagedObjectContext(moc)[0] as! Person
        XCTAssertNotNil(moc, "mainQueueMOC is nil")
        let otherMoc = doc.newChildOfMainObjectContextWithConcurrencyType()
        let p2 = p1.sameManagedObjectUsingManagedObjectContext(managedObjectContext: otherMoc) as! Person?
        otherMoc.performBlockAndWait { [unowned self] in
            XCTAssertNotNil(p2, "person in other MOC is nil")
            self.assertPerson(p2!, hasFirstName: "Dave", lastName: "Reed")
        }
        let objectID = p1.objectID
        otherMoc.performBlockAndWait { [unowned self] in
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
        let p = Person(managedObjectContext: moc)
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
