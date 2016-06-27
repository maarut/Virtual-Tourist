//
//  DownloadOperation.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 21/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation

class DownloadPhotoOperation: NSOperation
{
    private let incomingData = NSMutableData()
    private let photo: Photo
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
    
    init(photo: Photo)
    {
        self.photo = photo
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
            return
        }
        sessionTask = downloadTask
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
        photo.managedObjectContext?.performBlock {
            self.photo.imageData = NSData(data: self.incomingData)
            if self.photo.managedObjectContext!.hasChanges {
                do {
                    try self.photo.managedObjectContext!.save()
                }
                catch let error as NSError {
                    NSLog("\(error.description)\n\(error.localizedDescription)")
                }
            }
        }
    }
}

extension DownloadPhotoOperation: NSURLSessionDownloadDelegate
{
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask,
        didFinishDownloadingToURL location: NSURL)
    {
        defer { finished = true }
        if cancelled {
            cancelTask()
            return
        }
        incomingData.appendData(NSData(contentsOfURL: location)!)
    }
}

private extension DownloadPhotoOperation
{
    func task() -> NSURLSessionTask
    {
        let pathToResumeData = resumeDataURL()
        if let resumeData = NSData(contentsOfURL: pathToResumeData) {
            return session.downloadTaskWithResumeData(resumeData)
        }
        return session.downloadTaskWithURL(NSURL(string: photo.url!)!)
    }
    
    func resumeDataURL() -> NSURL
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
                let pathToResumeData = self.resumeDataURL()
                do {
                    try resumeData?.writeToURL(pathToResumeData, options: NSDataWritingOptions.init(rawValue:0))
                }
                catch let error as NSError {
                    NSLog("\(error.description)\n\(error.localizedDescription)")
                }
            })
        }
        else {
            sessionTask?.cancel()
        }
    }
}