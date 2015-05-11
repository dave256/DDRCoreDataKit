//
//  DDRCoreDataDocument.swift
//  DDRCoreDataKit
//
//  Created by David Reed on 6/13/14.
//  Copyright (c) 2014 David Reed. All rights reserved.
//

#if os(iOS)
    import UIKit
#endif

import CoreData

public enum DDRCoreDataSaveOrError {
    case SaveOkHadChanges(Bool) // Bool indicates if saved changes to persistentStore (i.e., hasChanges was true)
    case Error(NSError)
    case ErrorString(String)
}

public typealias DDRCoreDataDocumentCompletionClosure = (status: DDRCoreDataSaveOrError, doc: DDRCoreDataDocument?) -> Void

/**
class for accessing a Core Data Store

uses two NSManagedObjectContext
one context of type PrivateQueueConcurrencyType is used for saving to the store to avoid blocking the main thread; this context is private to the class

the mainQueueMOC is a child context of the private context and is intended for use with the GUI

also provides a method to get a child context of the mainQueueMOC

the saveContext method saves from the mainQueueMOC to the private context and to the persistent store

a combination of ideas from Zarra's book and this blog post

http://martiancraft.com/blog/2015/03/core-data-stack/

*/
public class DDRCoreDataDocument {

    /// the main thread/queue NSManagedObjectContext that should be used
    public let mainQueueMOC : NSManagedObjectContext!


    private let managedObjectModel : NSManagedObjectModel!
    private let persistentStoreCoordinator : NSPersistentStoreCoordinator!
    private let storeURL : NSURL!

    // private data
    private var privateMOC : NSManagedObjectContext! = nil

    /// create a DDRCoreDataDocument with two contexts; will fail (return nil) if cannot create the persistent store
    ///
    /// :param: storeURL NSURL for the SQLite store; pass nil to use an in memory store
    /// :param: modelURL NSURL for the CoreData object model (i.e., URL to the .momd file package/directory)
    /// :param: options to pass when creating the persistent store coordinator; if pass nil, it uses [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true] for automatic migration; pass an empty dictionary [ : ] if want no options
    public init?(storeURL: NSURL?, modelURL: NSURL, options : [NSObject : AnyObject]! = nil) {

        let pscOptions : [NSObject : AnyObject]

        // if passed in nil, use options for automatic migration otherwise used the specified options
        if options == nil {
            pscOptions = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        } else {
            pscOptions = options
        }

        // try to read model file
        managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL)

        // return nil if unable to
        if managedObjectModel == nil {
            persistentStoreCoordinator = nil
            mainQueueMOC = nil
            privateMOC = nil
            self.storeURL = nil
            return nil
        }

        var storeType : String = (storeURL != nil) ? NSSQLiteStoreType : NSInMemoryStoreType
        persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

        var localURL = storeURL
        var value: AnyObject?
        var isDirectory = false

        // if not an in memory store
        if storeType != NSInMemoryStoreType {
            // check if URL is a directory
            if (localURL!.getResourceValue(&value, forKey: NSURLIsDirectoryKey, error: nil)) {
                if value != nil {
                    isDirectory = value!.boolValue
                }
                // if it is a directory, try looking in directory for StoreContent/persistentStore as that is what UIManagedDocument uses
                if isDirectory {
                    localURL = localURL?.URLByAppendingPathComponent("StoreContent").URLByAppendingPathComponent("persistentStore")
                }
            }
        }

        // try to create the persistent store
        var addError : NSError? = nil
        if !(persistentStoreCoordinator.addPersistentStoreWithType(storeType, configuration: nil, URL: localURL, options: pscOptions, error: &addError) != nil) {
            if let error = addError {
                println("Error adding persitent store to coordinator \(error.localizedDescription) \(error.userInfo!)")
            }
            mainQueueMOC = nil
            privateMOC = nil
            self.storeURL = nil
            return nil

        } else {
            // if everything went ok creating persistent store
            self.storeURL = localURL
            // create the private MOC
            privateMOC = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
            privateMOC!.persistentStoreCoordinator = persistentStoreCoordinator
            privateMOC!.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

            // create the main thread/queue MOC that is a child context of the privateMOC
            mainQueueMOC = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
            mainQueueMOC!.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
            mainQueueMOC!.parentContext = privateMOC
        }
    }

    /// create a DDRCoreDataDocument with two contexts on a background thread
    ///
    /// :param: storeURL NSURL for the SQLite store; pass nil to use an in memory store
    /// :param: modelURL NSURL for the CoreData object model (i.e., URL to the .momd file package/directory)
    /// :param: options to pass when creating the persistent store coordinator; if pass nil, it uses [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true] for automatic migration; pass an empty dictionary [ : ] if want no options
    /// :param: completionClosure a closure (status: DDRCoreDataSaveOrError, doc: DDRCoreDataDocument?
    /// :post: calls completionClosure with DDRCoreDataSaveOrError.OK and the initialized DDRCoreDataDocument if success. otherwise completionClosure is called with DDRCoreDataSaveOrError.ErrorString and doc is nil
    public class func createInBackgroundWithCompletionHandler(storeURL: NSURL?, modelURL: NSURL, options : [NSObject : AnyObject]! = nil, completionClosure: DDRCoreDataDocumentCompletionClosure? = nil) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
            let doc = DDRCoreDataDocument(storeURL: storeURL, modelURL: modelURL, options: options)
            let status : DDRCoreDataSaveOrError
            if doc == nil {
                status = DDRCoreDataSaveOrError.ErrorString("Could not create DDRCoreDataDocument")
            }
            else {
                status = DDRCoreDataSaveOrError.SaveOkHadChanges(true)
            }
            dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                completionClosure?(status: status, doc: doc)
            })
        })
    }

    /// save the main and private contexts to the persistent store
    ///
    /// :param: wait true if want to wait for save to persistent store to complete; false if want to return as soon as main context saves to private context
    ///
    /// :returns: DDRCoreDataSaveOrError.Ok if save succeeds; DDRCoreDataSaveOrError.Error otherwise
    public func saveContextAndWait(wait: Bool) -> DDRCoreDataSaveOrError {
        if mainQueueMOC == nil {
            return DDRCoreDataSaveOrError.ErrorString("no NSManagedObjectContext")
        }

        var error: NSError!

        var failed = false
        // if mainQueueMOC has changes, save changes up to its parent context
        if mainQueueMOC.hasChanges {
            mainQueueMOC.performBlockAndWait {
                var saveError : NSError? = nil
                if self.mainQueueMOC.save(&saveError) {
                    if let theError = saveError {
                        failed = true
                        println("error saving mainQueueMOC: \(theError.localizedDescription)")
                        error = theError
                    }
                }
            }
        }

        // closure for saving private context
        var saveClosure : () -> () = {
        var saveError : NSError? = nil
            if !(self.privateMOC.save(&saveError)) {
                if let theError = saveError {
                    println("error saving privateMOC: \(theError.localizedDescription)")
                    failed = true
                    error = theError
                }
            }
        }

        var hasChanges = false
        // save changes from privateMOC to persistent store
        if !(failed) {
            privateMOC.performBlockAndWait() {
                hasChanges = self.privateMOC.hasChanges
            }
            if hasChanges {
                if wait {
                    privateMOC.performBlockAndWait(saveClosure)
                }
                else {
                    privateMOC.performBlock(saveClosure)
                }
            }
        }

        if failed {
            return DDRCoreDataSaveOrError.Error(error)
        } else {
            return DDRCoreDataSaveOrError.SaveOkHadChanges(hasChanges)
        }
    }


    #if os(iOS)
    /// save task on iOS so it runs even if app is quit
    public func saveContextWithBackgroundTask() {
        let backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler {}
        saveContextAndWait(true)
        UIApplication.sharedApplication().endBackgroundTask(backgroundTaskID)
    }
    #endif

    /// creates a new child NSManagedObjectContext of the main thread/queue context
    ///
    /// param: concurrencyType specifies the NSManagedObjectContextConcurrencyType for the created context
    ///
    /// :returns: the created NSManagedObjectContext
    public func newChildOfMainObjectContextWithConcurrencyType(concurrencyType : NSManagedObjectContextConcurrencyType = NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType) -> NSManagedObjectContext {
        var moc = NSManagedObjectContext(concurrencyType: concurrencyType)
        moc.parentContext = mainQueueMOC
        return moc
    }
}
