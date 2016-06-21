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
    convenience init(context: NSManagedObjectContext, url: String)
    {
        self.init(entity: NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!,
                    insertIntoManagedObjectContext: context)
        self.url = url
        downloadImage()
    }
    
    private func downloadImage()
    {
        if let url = NSURL(string: url ?? "") {
            NSURLSession.sharedSession().dataTaskWithURL(url, completionHandler: { (data, response, error) in
                guard error == nil else {
                    NSLog("\(error!.description)\n\(error!.localizedDescription)")
                    return
                }
                guard let data = data else {
                    NSLog("No data returned by request")
                    return
                }
                let statusCode = (response as! NSHTTPURLResponse).statusCode
                guard statusCode ~= 200 ..< 300 else {
                    NSLog("Bad status code received: \(statusCode)")
                    return
                }
                self.imageData = data
            }).resume()
        }
    }
}
