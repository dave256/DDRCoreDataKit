// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to Person.swift instead.

import CoreData

import DDRCoreDataKit

enum PersonAttributes: String {
    case firstName = "firstName"
    case lastName = "lastName"
}

@objc public
class _Person: DDRManagedObject {

    // MARK: - Class methods

    override public class func entityName () -> String {
        return "Person"
    }

    override public class func entity(managedObjectContext: NSManagedObjectContext!) -> NSEntityDescription! {
        return NSEntityDescription.entityForName(self.entityName(), inManagedObjectContext: managedObjectContext);
    }

    // MARK: - Life cycle methods

    public
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext!) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

	public
    convenience init(managedObjectContext: NSManagedObjectContext!) {
        let entity = _Person.entity(managedObjectContext)
        self.init(entity: entity, insertIntoManagedObjectContext: managedObjectContext)
    }

    // MARK: - Properties

    @NSManaged public
    var firstName: String?

    // func validateFirstName(value: AutoreleasingUnsafePointer<AnyObject>, error: NSErrorPointer) {}

    @NSManaged public
    var lastName: String?

    // func validateLastName(value: AutoreleasingUnsafePointer<AnyObject>, error: NSErrorPointer) {}

    // MARK: - Relationships

}

