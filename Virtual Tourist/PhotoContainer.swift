//
//  PhotoContainer.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 08/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation
import CoreData


class PhotoContainer: NSManagedObject
{
    convenience init(context: NSManagedObjectContext, pin: Pin)
    {
        self.init(entity: NSEntityDescription.entityForName("PhotoContainer", inManagedObjectContext: context)!,
            insertIntoManagedObjectContext: context)
        self.pin = pin
    }
}
