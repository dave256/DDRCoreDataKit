//
//  DDRSyncedManagedObject.swift
//  DDRCoreDataKit
//
//  Created by David Reed on 6/19/14.
//  Copyright (c) 2014 David Reed. All rights reserved.
//

import Foundation

/**
since this code now uses mogenerator, if you want some of the classes to have thsese methods, copy the following methods into the non-generated file

or if you want all your files to have thse, you could tell mogenerator to inherit from DDRSyncedManagedObject instead of DDRManagedObject

this class assumes your Core Data entity has an attribute of type string named ddrSyncIdentifier
*/
public class DDRSyncedManagedObject : DDRManagedObject {

    /// sets the ddrSyncIdentifier to a unique value
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        var desc = self.entity
        if desc.attributesByName["ddrSyncIdentifier"] != nil {
            self.setValue(NSUUID().UUIDString, forKey: "ddrSyncIdentifier")
        }
    }

    /// override valueForUndefinedKey: so can print an error message if user forgets to add an attribute named ddrSyncIdentifier to their CoreData model
    public override func valueForUndefinedKey(key: String) -> AnyObject {
        if key == "ddrSyncIdentifier" {
            let name = DDRManagedObject.entityName()
            println("no ddrSyncIdentifier for object of type: \(name)")
        } else {
            super.valueForUndefinedKey(key)
        }
        return ""
    }

    /// override value:forUndefinedKey so can print an error message if user forgets to add an attribute named ddrSyncIdentifier to their CoreData model
    public override func setValue(value: AnyObject!, forUndefinedKey key: String) {
        if key == "ddrSyncIdentifier" {
            println("no ddrSyncIdentifier for object of type")
        } else {
            super.setValue(value, forUndefinedKey: key)
        }
    }

}

