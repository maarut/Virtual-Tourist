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

        do {
            let options = [NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true]
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: dbURL,
                options: options)
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
        context.performBlockAndWait {
            if self.context.hasChanges {
                do { try self.context.save() }
                catch let error as NSError { logErrorAndAbort(error) }
            }
        }
        persistingContext.performBlock {
            if self.persistingContext.hasChanges {
                do { try self.persistingContext.save() }
                catch let error as NSError { logErrorAndAbort(error) }
            }
        }
    }
    
    func delete(object: NSManagedObject)
    {
        context.performBlock {
            self.context.deleteObject(object)
            self.save()
        }
    }
    
    func createPin(longitude longitude: Double, latitude: Double, title: String = "") -> Pin
    {
        let pin = Pin(title: title, longitude: longitude, latitude: latitude, context: context)
        self.save()
        searchForImagesAt(pin)
        return pin
    }
    
    func searchForImagesAt(pin: Pin, isImageRefresh: Bool = false)
    {
        let imageSearchContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        imageSearchContext.name = "Image Search Context"
        imageSearchContext.parentContext = context
        
        let criteria = createCriteriaFor(pin, isImageRefresh: isImageRefresh)
        let imageSearch = FlickrImageSearch(criteria: criteria, insertResultsInto: pin, using: imageSearchContext)
        let searchOp = FlickrNetworkOperation(processor: imageSearch)
        let imageDownloadOp = NSBlockOperation {
            let pin = self.context.objectWithID(pin.objectID) as! Pin  
            let ops = self.createDownloadWithSaveOperationsFor(
                (pin.photoContainer as? PhotoContainer)?.photos?.array as? [Photo] ?? [])
            let saveOp = NSBlockOperation { self.save() }
            for o in ops { saveOp.addDependency(o) }
            self.networkOperationQueue.addOperations(ops + [saveOp], waitUntilFinished: false)
        }
        imageDownloadOp.addDependency(searchOp)
        networkOperationQueue.addOperations([searchOp, imageDownloadOp], waitUntilFinished: false)
    }
    
    func downloadImageFor(photo: Photo)
    {
        let saveOp = NSBlockOperation { self.save() }
        let downloadOps = createDownloadWithSaveOperationsFor([photo])
        for op in downloadOps { saveOp.addDependency(op) }
        networkOperationQueue.addOperations(downloadOps + [saveOp], waitUntilFinished: false)
    }
}

// MARK: - Private Methods
private extension DataController
{
    func createCriteriaFor(pin: Pin, isImageRefresh: Bool) -> FlickrImageSearchCriteria
    {
        if isImageRefresh {
            if let photoContainer = pin.photoContainer as? PhotoContainer {
                let page = (photoContainer.page!.integerValue + 1) % (photoContainer.pageCount!.integerValue + 1)
                return FlickrImageSearchCriteria(longitude: pin.longitude!.doubleValue,
                    latitude: pin.latitude!.doubleValue, limit: photoContainer.perPage!.integerValue,
                    searchResultPageNumber: page)
            }
        }
        if let photoContainer = pin.photoContainer as? PhotoContainer {
            return FlickrImageSearchCriteria(longitude: pin.longitude!.doubleValue, latitude: pin.latitude!.doubleValue,
                limit: photoContainer.perPage!.integerValue, searchResultPageNumber: photoContainer.page!.integerValue)
        }
        return FlickrImageSearchCriteria(longitude: pin.longitude!.doubleValue, latitude: pin.latitude!.doubleValue,
            limit: 100, searchResultPageNumber: 1)
    }
    
    func createDownloadWithSaveOperationsFor(photos: [Photo]) -> [NSOperation]
    {
        let mappedElements: [[NSOperation]] = photos.map { photo in
            let downloadContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
            downloadContext.name = "Photo Download Context"
            downloadContext.parentContext = self.context
            let photo = downloadContext.objectWithID(photo.objectID) as! Photo
            let downloadOp = DownloadPhotoOperation(photo: photo, saveInto: downloadContext)
            let saveOp = NSBlockOperation {
                downloadContext.performBlockAndWait {
                    if downloadContext.hasChanges {
                        do { try downloadContext.save() }
                        catch let error as NSError { NSLog("\(error.description)\n\(error.localizedDescription)") }
                    }
                }
            }
            saveOp.addDependency(downloadOp)
            return [downloadOp, saveOp]
        }
        return Array(mappedElements.flatten())
    }
}

// MARK: - Private Functions
private func logErrorAndAbort(error: NSError)
{
    var errorString = "Core Data Error: \(error.localizedDescription)\n\(error)\n"
    if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
        detailedErrors.forEach { errorString += "\($0.localizedDescription)\n\($0)\n" }
    }
    fatalError(errorString)
}
