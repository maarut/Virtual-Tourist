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
    
    let mainThreadContext: NSManagedObjectContext
    
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
        
        mainThreadContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        mainThreadContext.name = "Main"
        mainThreadContext.parentContext = persistingContext

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
        mainThreadContext.performBlockAndWait {
            if self.mainThreadContext.hasChanges {
                do { try self.mainThreadContext.save() }
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
    
    func deleteObjectsFromMainContext(objects: [NSManagedObject])
    {
        mainThreadContext.performBlock {
            for o in objects { self.mainThreadContext.deleteObject(o) }
            self.save()
        }
    }
    
    func deleteFromMainContext(object: NSManagedObject)
    {
        deleteObjectsFromMainContext([object])
    }
}

// These methods must be called from the performBlock or performBlockAndWait of an NSManagedObjectContext
extension DataController
{
    func createPin(longitude longitude: Double, latitude: Double, title: String = "") -> Pin
    {
        let pin = Pin(title: title, longitude: longitude, latitude: latitude, context: mainThreadContext)
        self.save()
        searchForImagesAt(pin)
        return pin
    }
    
    func searchForImagesAt(pin: Pin, isImageRefresh: Bool = false)
    {
        let imageSearchContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        imageSearchContext.name = "Image Search Context"
        imageSearchContext.parentContext = mainThreadContext
        let pinId = pin.objectID
        let criteria = createCriteriaFor(pin, isImageRefresh: isImageRefresh)
        let imageSearch = FlickrImageSearch(criteria: criteria, insertResultsInto: pin, using: imageSearchContext)
        let searchOp = FlickrNetworkOperation(processor: imageSearch)
        let imageDownloadOp = NSBlockOperation {
            self.mainThreadContext.performBlockAndWait {
                let pin = self.mainThreadContext.objectWithID(pinId) as! Pin
                let ops = self.createDownloadWithSaveOperationsFor(
                    (pin.photoContainer as? PhotoContainer)?.photos?.array as? [Photo] ?? [])
                let saveOp = NSBlockOperation { self.save() }
                for o in ops { saveOp.addDependency(o) }
                self.networkOperationQueue.addOperations(ops + [saveOp], waitUntilFinished: false)
            }
        }
        imageDownloadOp.addDependency(searchOp)
        networkOperationQueue.addOperations([searchOp, imageDownloadOp], waitUntilFinished: false)
    }
    
    func downloadImageFor(photo: Photo)
    {
        let saveOp = NSBlockOperation { self.save() }
        let downloadOps = self.createDownloadWithSaveOperationsFor([photo])
        for op in downloadOps { saveOp.addDependency(op) }
        self.networkOperationQueue.addOperations(downloadOps + [saveOp], waitUntilFinished: false)
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
            limit: 25, searchResultPageNumber: 1)
    }
    
    func createDownloadWithSaveOperationsFor(photos: [Photo]) -> [NSOperation]
    {
        var mappedElements = [NSOperation]()
        for photo in photos {
            let downloadContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
            downloadContext.name = "Photo Download Context for \(photo.id!.integerValue)"
            downloadContext.parentContext = self.mainThreadContext
            
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
            mappedElements += [downloadOp, saveOp]
        }
        return mappedElements
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
