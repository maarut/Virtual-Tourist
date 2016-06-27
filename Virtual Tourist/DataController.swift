//
//  CoreDataStack.swift
//  CoreDataTest
//
//  Created by Maarut Chandegra on 31/05/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation
import CoreData

class DataController
{
    private let networkOperationQueue = NSOperationQueue()
    private let model: NSManagedObjectModel
    private let coordinator: NSPersistentStoreCoordinator
    private let dbURL: NSURL
    private let persistingContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    
    let context: NSManagedObjectContext
    
    init?(withModelName modelName: String)
    {
        guard let modelUrl = NSBundle.mainBundle().URLForResource(modelName, withExtension: "momd") else {
            NSLog("Unable to find model in bundle")
            return nil
        }
        guard let model = NSManagedObjectModel(contentsOfURL: modelUrl) else {
            NSLog("Unable to create object model")
            return nil
        }
        guard let docsDir = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory,
                                                                            inDomains: .UserDomainMask).first else {
            NSLog("Unable to obtain Documents directory for user")
            return nil
        }
        self.model = model
        coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        dbURL = docsDir.URLByAppendingPathComponent("\(modelName).sqlite")
        
        persistingContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        persistingContext.name = "Persisting"
        persistingContext.persistentStoreCoordinator = coordinator
        
        context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        context.name = "Main"
        context.parentContext = persistingContext
        
        backgroundContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        backgroundContext.name = "Background"
        backgroundContext.parentContext = context

        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: dbURL, options: nil)
        }
        catch let error as NSError {
            logErrorAndAbort(error)
        }
    }
    
    func dropAllData() throws
    {
        try coordinator.destroyPersistentStoreAtURL(dbURL, withType: NSSQLiteStoreType, options: nil)
        try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: dbURL, options: nil)
    }
    
    func save()
    {
        if context.hasChanges {
            do {
                try context.save()
                persistingContext.performBlock {
                    if self.persistingContext.hasChanges {
                        do {
                            try self.persistingContext.save()
                        }
                        catch let error as NSError {
                            logErrorAndAbort(error)
                        }
                    }
                }
            }
            catch let error as NSError {
                logErrorAndAbort(error)
            }
        }
    }
    
    func createPin(longitude longitude: Double, latitude: Double, title: String = "") -> Pin
    {
        let pin = Pin(title: title, longitude: longitude, latitude: latitude, context: backgroundContext)
        searchForImagesAt(pin)
        return pin
    }
    
    func searchForImagesAt(pin: Pin, isImageRefresh: Bool = false)
    {
        let criteria = createCriteriaFor(pin, isImageRefresh: isImageRefresh)
        let imageSearch = FlickrImageSearch(criteria: criteria, insertResultsInto: pin)
        let searchOp = FlickrNetworkOperation(processor: imageSearch)
        let imageDownloadOp = NSBlockOperation { 
            let ops = self.createDownloadPhotoOperations(pin)
            let saveOp = NSBlockOperation {
                pin.managedObjectContext?.performBlock {
                    if pin.managedObjectContext!.hasChanges {
                        do {
                            try pin.managedObjectContext!.save()
                        }
                        catch let error as NSError {
                            NSLog("\(error.description)\n\(error.localizedDescription)")
                        }
                    }
                    self.save()
                }
            }
            for o in ops { saveOp.addDependency(o) }
            self.networkOperationQueue.addOperations(ops + [saveOp], waitUntilFinished: false)
        }
        imageDownloadOp.addDependency(searchOp)
        networkOperationQueue.addOperations([searchOp, imageDownloadOp], waitUntilFinished: false)
    }
}

private extension DataController
{
    func createCriteriaFor(pin: Pin, isImageRefresh: Bool) -> FlickrImageSearchCriteria
    {
        if isImageRefresh {
            if let photoContainer = pin.photoContainer as? PhotoContainer {
                return FlickrImageSearchCriteria(longitude: pin.longitude!.doubleValue,
                                                 latitude: pin.latitude!.doubleValue, limit: photoContainer.perPage!.integerValue,
                                                 searchResultPageNumber: photoContainer.page!.integerValue + 1)
            }
        }
        return FlickrImageSearchCriteria(longitude: pin.longitude!.doubleValue, latitude: pin.latitude!.doubleValue,
                                         limit: 100, searchResultPageNumber: 1)
    }
    
    func createDownloadPhotoOperations(pin: Pin) -> [DownloadPhotoOperation]
    {
        return (pin.photoContainer as? PhotoContainer)?.photos?.array.map {
            DownloadPhotoOperation(photo: $0 as! Photo)
            } ?? []
    }
}

private func logErrorAndAbort(error: NSError)
{
    var errorString = "Core Data Error: \(error.localizedDescription)\n\(error)\n"
    if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
        detailedErrors.forEach { errorString += "\($0.localizedDescription)\n\($0)\n" }
    }
    fatalError(errorString)
}
