//
//  Photo+CoreDataProperties.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 30/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Photo {

    @NSManaged var id: NSNumber?
    @NSManaged var imageData: NSData?
    @NSManaged var url: String?
    @NSManaged var isDownloading: NSNumber?
    @NSManaged var photoContainer: PhotoContainer?

}
