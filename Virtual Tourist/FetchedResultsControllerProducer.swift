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
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil,
                                            cacheName: nil)
    }
}