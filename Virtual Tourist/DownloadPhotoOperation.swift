//
//  DownloadOperation.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 21/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation
import CoreData

// MARK: - NSOperation Overrides
class DownloadPhotoOperation: NSOperation
{
    private let incomingData = NSMutableData()
    private let photoId: NSManagedObjectID
    private let context: NSManagedObjectContext
    private var sessionTask: NSURLSessionTask?
    private lazy var session: NSURLSession = {
        return NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(),
            delegate: self, delegateQueue: nil)
    }()
    
    var _finished: Bool = false
    override var finished: Bool {
        get {
            return _finished
        }
        set {
            willChangeValueForKey("isFinished")
            _finished = newValue
            didChangeValueForKey("isFinished")
        }
    }
    
    init(photo: Photo, saveInto context: NSManagedObjectContext)
    {
        self.photoId = photo.objectID
        self.context = context
        super.init()
    }
    
    override func start()
    {
        if cancelled {
            finished = true
            return
        }
        sessionTask = task()
        sessionTask!.resume()
    }
}

// MARK: - NSURLSessionDelegate Implementation
extension DownloadPhotoOperation: NSURLSessionDelegate
{
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse,
        completionHandler: (NSURLSessionResponseDisposition) -> Void)
    {
        if cancelled {
            sessionTask?.cancel()
            finished = true
            completionHandler(.Cancel)
            return
        }
        if let response = response as? NSHTTPURLResponse {
            if !(response.statusCode ~= 200 ..< 300) {
                completionHandler(.Cancel)
            }
        }
        completionHandler(.BecomeDownload)
    }
    
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask,
        didBecomeDownloadTask downloadTask: NSURLSessionDownloadTask)
    {
        if cancelled {
            downloadTask.cancel()
            finished = true
            setIsDownloading(false)
            return
        }
        sessionTask = downloadTask
        setIsDownloading(true)
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?)
    {
        defer { finished = true }
        if cancelled {
            cancelTask()
            return
        }
        guard error == nil else {
            NSLog("\(error!.description)\n\(error!.localizedDescription)")
            return
        }
        context.performBlockAndWait {
            let photo = self.context.objectWithID(self.photoId) as! Photo
            photo.imageData = NSData(data: self.incomingData)
            do { try self.context.save() }
            catch let error as NSError {
                self.context.rollback()
                NSLog("Derp\(error.localizedDescription)\n\(error.description)")
            }
        }
    }
}

// MARK: - NSURLSessionDownloadDelegate Implementation
extension DownloadPhotoOperation: NSURLSessionDownloadDelegate
{
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask,
        didFinishDownloadingToURL location: NSURL)
    {
        if cancelled {
            finished = true
            cancelTask()
            return
        }
        incomingData.appendData(NSData(contentsOfURL: location)!)
    }
}

// MARK: - Private Methods
private extension DownloadPhotoOperation
{
    func setIsDownloading(isDownloading: Bool)
    {
        context.performBlockAndWait {
            let photo = self.context.objectWithID(self.photoId) as! Photo
            photo.isDownloading = isDownloading
            do { try self.context.save() }
            catch let error as NSError {
                NSLog("Could not save isDownloading for Photo: \(photo)\n" +
                    "\(error.description)\n\(error.localizedDescription)")
            }
        }
    }
    
    func task() -> NSURLSessionTask
    {
        let photo = context.objectWithID(photoId) as! Photo
        let pathToResumeData = resumeDataURLFor(photo)
        if let resumeData = NSData(contentsOfURL: pathToResumeData) {
            return session.downloadTaskWithResumeData(resumeData)
        }
        return session.downloadTaskWithURL(NSURL(string: photo.url!)!)
    }
    
    func resumeDataURLFor(photo: Photo) -> NSURL
    {
        let cacheDirs = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask)
        if let cacheDir = cacheDirs.first {
            return cacheDir.URLByAppendingPathComponent("\(photo.id!.integerValue).resumeData")
        }
        return NSURL()
    }
    
    func cancelTask()
    {
        if let sessionTask = sessionTask as? NSURLSessionDownloadTask {
            sessionTask.cancelByProducingResumeData({ (resumeData) in
                let photo = self.context.objectWithID(self.photoId) as! Photo
                let pathToResumeData = self.resumeDataURLFor(photo)
                do { try resumeData?.writeToURL(pathToResumeData, options: NSDataWritingOptions.init(rawValue:0)) }
                catch let error as NSError { NSLog("\(error.description)\n\(error.localizedDescription)") }
            })
        }
        else {
            sessionTask?.cancel()
        }
        setIsDownloading(false)
    }
}