//
//  DDRManagedObject.swift
//  DDRCoreDataKit
//
//  Created by David Reed on 6/13/14.
//  Copyright (c) 2014 David Reed. All rights reserved.
//

import CoreData

/**
DDRManagedObject is a standard subclass of NSManagedObject with convenience methods for creating new instances and fetch requests

it is intended for use with mogenerator such that the mogenerator created base class (the one that starts with an _) will subclass DDRManagedObject

put code such as the following in a Run Script build phase and move it before the compile step
If you manually added the DDRManagedObject.swift file to your project, you will want to use something like:
cd "$PROJECT_DIR/$TARGET_NAME" && /Users/dreed/bin/mogenerator --swift -m "$TARGET_NAME".xcdatamodeld --base-class DDRManagedObject --output-dir ./ModelObjects

If you add the DDRCoreDataKit project as a module to your Xcode workspace, you will want to use something like:
cd "$PROJECT_DIR/$TARGET_NAME" && $HOME/bin/mogenerator --swift -m "$TARGET_NAME".xcdatamodeld --base-class DDRManagedObject --base-class-import DDRCoreDataKit  --output-dir ./ModelObjects

note: uses own version of mogenerator in https://github.com/dave256/mogenerator/tree/swift-public
so that --base-class-import DDRCoreDataKit adds the statment "import DDRCoreDataKit" to the machine generated file (one that starts with an underscore)

if you intend to use without mogenerator (not recommended), your subclass must use the syntax:

@objc(Person) class Person : DDRManagedObject

otherwise entityName method will not work
*/
public class DDRManagedObject: NSManagedObject {

    //----------------------------------------------------------------------
    // MARK:- class methods

    /// overriden by MOGenerator generated base class
    public class func entityName() -> String {
        return ""
    }

    /// overriden by MOGenerator generated base class
    public class func entity(managedObjectContext: NSManagedObjectContext!) -> NSEntityDescription! {
        return nil // NSEntityDescription.entityForName(self.entityName(), inManagedObjectContext: managedObjectContext);
    }

    /// :returns: a NSFetchRequest for entities (your subclass)
    public class func fetchRequest() -> NSFetchRequest {
        return NSFetchRequest(entityName: entityName())
    }

    /// get objects of this entity that match predicate and sorted by sort descriptors
    ///
    /// :param: predicate the NSPredicate to limit which objects are returned
    /// :param: sortDescriptors array of NSSortDescriptors to use to sort the returned array
    /// :param: inManagedObjectContext the NSManagedObjectContext to use
    /// :returns: array of instances that match pedicate sorted by sortDescriptors
    public class func allInstancesWithPredicate(predicate: NSPredicate?, sortDescriptors : [NSSortDescriptor]?, inManagedObjectContext moc: NSManagedObjectContext) -> [AnyObject]! {

        // create a new fetch request using instance method
        var request = fetchRequest()

        // set fetch request predicte if passed in
        if let pred = predicate {
            request.predicate = pred
        }

        // set fetch request sort descriptors if passed in
        if let sorters = sortDescriptors {
            request.sortDescriptors = sorters
        }

        // execute request
        let (results, executeError) = moc.executeFetchRequest(request)
        if let error = executeError {
            println("Error loading \(request) \(predicate) \(error)")
        }

        // return array of NSManagedObjects (array of your subclass of NSManagedObjects)
        return results
    }

    /// get objects of this entity that match predicate
    ///
    /// :param: predicate the NSPredicate to limit which objects are returned
    /// :param: inManagedObjectContext the NSManagedObjectContext to use
    /// :returns: array of instances that match pedicate sorted by sortDescriptors
    public class func allInstancesWithPredicate(predicate: NSPredicate?, inManagedObjectContext moc: NSManagedObjectContext) -> [AnyObject]! {
        return allInstancesWithPredicate(predicate, sortDescriptors: nil, inManagedObjectContext: moc)
    }

    /// get all objects of this entity
    ///
    /// :param: inManagedObjectContext the NSManagedObjectContext to use
    /// :returns: array of instances that match pedicate sorted by sortDescriptors
    public class func allInstances(managedObjectContext moc : NSManagedObjectContext) -> [AnyObject]! {
        return self.allInstancesWithPredicate(nil, sortDescriptors: nil, inManagedObjectContext: moc)
    }


    //----------------------------------------------------------------------
    // MARK:- instance methods

    /// delete the object from its NSManagedObjectContext and call processPendingChanges to force cascade delete of any relationships now
    ///
    /// :post: the object is deleted from its MOC and prcoessPendingChanges is called to force cascade delete of any relationships now
    public func deleteObjectAndProcessPendingChanges() {
        let moc = self.managedObjectContext
        moc?.deleteObject(self)
        moc?.processPendingChanges()
    }

    /// returns an NSManagedObject for the same object using the specifed managedObjectContext (or nil if non-temporary objectID)
    ///
    /// :pre: this NSManagedObject has a non-temporary objectID (otherwise returns nil)
    /// :param: managedObjectContext the managedObjectContext to get the duplicate object on
    /// :returns: an NSManagedObject for the same object using the specifed managedObjectContext (or nil if non-temporary objectID)
    public func sameManagedObjectUsingManagedObjectContext(managedObjectContext otherMoc: NSManagedObjectContext) -> NSManagedObject? {
        if (self.managedObjectContext!.isEqual(otherMoc)) {
            #if DEBUG
                println("cannot use same managedObjectContext or will deadlock so return self")
            #endif
            return self
        }

        let objectID = self.objectID
        if objectID.temporaryID {
            println("cannot use objectID that is temporaryID; must save context first")
            return nil
        }
        var otherObject: NSManagedObject? = nil
        otherMoc.performBlockAndWait {
            var error: NSError? = nil
            otherObject = otherMoc.existingObjectWithID(objectID, error: &error)
            if error != nil {
                otherObject = nil
                #if DEBUG
                    println("Error: existingObjectWithID \(error!.localizedDescription) \(error!.userInfo!)")
                #endif
            }
        }

        return otherObject
    }
}
