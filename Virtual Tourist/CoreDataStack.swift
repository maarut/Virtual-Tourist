//
//  CoreDataStack.swift
//  CoreDataTest
//
//  Created by Maarut Chandegra on 31/05/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation
import CoreData

class CoreDataStack
{
    static let instance: CoreDataStack = {
        if let i = CoreDataStack() { return i }
        fatalError("Unable to instantiate Core Data stack")
    }()
    
    private static let modelFileName = "VirtualTouristModel"
    
    private let model: NSManagedObjectModel
    private let coordinator: NSPersistentStoreCoordinator
    private let dbURL: NSURL
    private let persistingContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    
    let context: NSManagedObjectContext
    
    private init?()
    {
        guard let modelUrl = NSBundle.mainBundle().URLForResource(CoreDataStack.modelFileName, withExtension: "momd") else {
            NSLog("Unable to find model in bundle")
            return nil
        }
        guard let model = NSManagedObjectModel(contentsOfURL: modelUrl) else {
            NSLog("Unable to create object model")
            return nil
        }
        guard let docsDir = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first else {
            NSLog("Unable to obtain Documents directory for user")
            return nil
        }
        self.model = model
        coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        dbURL = docsDir.URLByAppendingPathComponent("\(CoreDataStack.modelFileName).sqlite")
        
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
    
    func performBackgroundTask(batch: NSManagedObjectContext -> ())
    {
        backgroundContext.performBlock {
            batch(self.backgroundContext)
            do {
                try self.backgroundContext.save()
            }
            catch let error as NSError {
                logErrorAndAbort(error)
            }
        }
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
    
    func autoSaveWithInterval(interval: Int64)
    {
        if interval > 0 {
            save()
            let nextIteration = dispatch_time(DISPATCH_TIME_NOW, interval * Int64(NSEC_PER_SEC))
            
            dispatch_after(nextIteration, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
                self.autoSaveWithInterval(interval)
            }
        }
    }
}

private func logErrorAndAbort(error: NSError)
{
    var errorString = "Error while saving: \(error.localizedDescription)\n\(error)\n"
    if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
        for e in detailedErrors {
            errorString += "\(e.localizedDescription)\n\(e)\n"
        }
    }
    fatalError(errorString)
}
