//
//  FlickrOperation.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 10/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation

protocol FlickrNetworkOperationProcessor: AnyObject
{
    var request: NSURLRequest { get }
    func processData(data: NSData)
    func handleError(error: NSError)
}

class FlickrNetworkOperation: NSOperation
{
    private let incomingData = NSMutableData()
    private var sessionTask: NSURLSessionTask?
    private lazy var session: NSURLSession = {
        return NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(),
                     delegate: self, delegateQueue: nil)
    }()
    private var processor: FlickrNetworkOperationProcessor
    
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
    
    init(processor: FlickrNetworkOperationProcessor)
    {
        self.processor = processor
        super.init()
    }
    
    override func start()
    {
        if cancelled {
            finished = true
            return
        }
        sessionTask = session.dataTaskWithRequest(processor.request)
        sessionTask!.resume()
    }
}

extension FlickrNetworkOperation: NSURLSessionDataDelegate
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
        completionHandler(.Allow)
    }
    
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData)
    {
        if cancelled {
            sessionTask?.cancel()
            finished = true
            return
        }
        incomingData.appendData(data)
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?)
    {
        defer { finished = true }
        if cancelled {
            sessionTask?.cancel()
            return
        }
        guard error == nil else {
            processor.handleError(error!)
            return
        }
        processor.processData(NSData(data: incomingData))
        
    }
}
