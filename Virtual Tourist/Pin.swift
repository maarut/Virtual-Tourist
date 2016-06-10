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
        populatePhotoContainer(latitude: latitude, longitude: longitude)
    }
    
    private func populatePhotoContainer(latitude latitude: Double, longitude: Double)
    {
        FlickrClient.sharedInstance().imagesNearLatitude(latitude, longitude: longitude) { (photos, error) in
            guard error == nil else {
                NSLog("\(error?.localizedDescription)\n\(error)")
                return
            }
            guard let photos = photos else {
                return
            }
            let photoContainer = PhotoContainer(context: self.managedObjectContext!, pin: self)
            photoContainer.page = photos.page
            photoContainer.pageCount = photos.pages
            photoContainer.total = photos.total
            photoContainer.perPage = photos.perPage
            let photoArray = photos.photos.map { Photo(context: self.managedObjectContext!, url: $0.url.absoluteString) }
            photoContainer.photos = NSSet(array: photoArray)
        }
    }
}
