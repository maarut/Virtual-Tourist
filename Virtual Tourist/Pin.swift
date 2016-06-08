//
//  Pin.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 08/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation
import CoreData


class Pin: NSManagedObject
{
    convenience init(title: String, longitude: Double, latitude: Double, context: NSManagedObjectContext)
    {
        self.init(entity: NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        self.title = title
        self.longitude = longitude
        self.latitude = latitude
    }
}
