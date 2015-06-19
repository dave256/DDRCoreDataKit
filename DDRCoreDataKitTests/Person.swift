//
//  Person.swift
//  DDRCoreDataKit
//
//  Created by David Reed on 6/19/15.
//  Copyright © 2015 David Reed. All rights reserved.
//

import Foundation
import CoreData
import DDRCoreDataKit

@objc(Person)
public class Person: NSManagedObject, DDRManagedObject {

    public static func entityName() -> String {
        return "Person"
    }

    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext!) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

    public required convenience init(managedObjectContext: NSManagedObjectContext!) {
        let entity = self.dynamicType.entity(managedObjectContext)
        self.init(entity: entity, insertIntoManagedObjectContext: managedObjectContext)
    }

}
