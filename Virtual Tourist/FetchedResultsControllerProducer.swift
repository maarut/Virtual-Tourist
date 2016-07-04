//
//  FetchedResultsControllerProducer.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 07/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation
import CoreData

extension DataController
{
    func allPinsWithSortDescriptor(sortDescriptor: NSSortDescriptor) -> NSFetchedResultsController
    {
        let request = NSFetchRequest(entityName: "Pin")
        request.sortDescriptors = [sortDescriptor]
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: mainThreadContext,
            sectionNameKeyPath: nil, cacheName: nil)
    }
    
    func allPhotosFor(pin: Pin) -> NSFetchedResultsController
    {
        let request = NSFetchRequest(entityName: "Photo")
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        request.predicate = NSPredicate(format: "photoContainer.pin == %@", pin)
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: mainThreadContext,
            sectionNameKeyPath: nil, cacheName: nil)
    }
    
    func fetchedResultsControllerFor(pin: Pin) -> NSFetchedResultsController
    {
        let request = NSFetchRequest(entityName: "Pin")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        request.predicate = NSPredicate(format: "SELF == %@", pin)
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: mainThreadContext,
            sectionNameKeyPath: nil, cacheName: nil)
    }
}