//
//  DDRManagedObjectContext.swift
//  DDRCoreDataKit
//
//  Created by David M Reed on 4/2/15.
//  Copyright (c) 2015 David Reed. All rights reserved.
//

import CoreData

public extension NSManagedObjectContext {

    public func executeFetchRequest(request: NSFetchRequest) -> ([AnyObject]?, NSError?) {
        var error: NSError? = nil
        let items = executeFetchRequest(request, error: &error)
        return (items, error)
    }
}
