//
//  Photo.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 08/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation
import CoreData

class Photo: NSManagedObject
{
    convenience init(context: NSManagedObjectContext, id: Int, url: String)
    {
        self.init(entity: NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!,
            insertIntoManagedObjectContext: context)
        self.url = url
        self.id = id
        self.isDownloading = NSNumber(bool: false)
    }
    
    // Wrapper property because isDownloading is stored as an NSNumber
    var isDownloadingImage: Bool {
        get {
            return isDownloading!.boolValue
        }
    }
}
