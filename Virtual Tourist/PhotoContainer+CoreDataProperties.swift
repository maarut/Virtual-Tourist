//
//  PhotoContainer+CoreDataProperties.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 08/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension PhotoContainer {

    @NSManaged var page: NSNumber?
    @NSManaged var pageCount: NSNumber?
    @NSManaged var total: NSNumber?
    @NSManaged var perPage: NSNumber?
    @NSManaged var photos: NSSet?
    @NSManaged var pin: Pin?

}
