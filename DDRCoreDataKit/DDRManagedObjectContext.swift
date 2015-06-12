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
        let items: [AnyObject]?
        do {
            items = try executeFetchRequest(request)
        } catch let error1 as NSError {
            error = error1
            items = nil
        }
        return (items, error)
    }
}
