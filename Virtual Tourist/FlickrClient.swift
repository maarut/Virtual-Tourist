//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 02/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation

enum FlickrClientErrorCodes: Int
{
    case NoData
    case BadStatusCode
    case JSONParse
    case KeyNotFound
}

class FlickrClient
{
    // MARK: - Class Methods
    static func sharedInstance() -> FlickrClient
    {
        struct DispatchOnce { static var token = 0; static var value: FlickrClient! }
        dispatch_once(&DispatchOnce.token) { DispatchOnce.value = FlickrClient() }
        return DispatchOnce.value
    }
    
    // MARK: - Private Members
    private let sharedSessionLock = NSLock()
    private var _sharedSession: NSURLSession
    
    // MARK: - Public Properties
    var sharedSession: NSURLSession {
        get {
            sharedSessionLock.lock()
            defer { sharedSessionLock.unlock() }
            return _sharedSession
        }
        set {
            sharedSessionLock.lock()
            defer { sharedSessionLock.unlock() }
            _sharedSession = newValue
        }
    }
    
    // MARK: - Lifecycle
    private init() { _sharedSession = NSURLSession.sharedSession() }
    
    // MARK: - Public Methods
    func imagesNearLatitude(latitude: Double, longitude: Double, limit: Int = 100, pageNumber: Int = 1, completionHandler: (FlickrPhotos?, NSError?) -> Void) -> NSURLSessionDataTask
    {
        let parameters: [String: AnyObject] = [
            Constants.ParameterKeys.Method: Constants.Methods.Search,
            Constants.ParameterKeys.Extras: FlickrClient.parameterValueForImageSize(.Medium),
            Constants.ParameterKeys.Longitude: longitude,
            Constants.ParameterKeys.Latitude: latitude,
            Constants.ParameterKeys.SafeSearch: Constants.ParameterValues.SafeSearchOn,
            Constants.ParameterKeys.PerPageLimit: limit,
            Constants.ParameterKeys.Page: pageNumber
        ]
        let task = taskForGETRequest(parameters) { (parsedData, error) in
            func sendError(userInfo: [String: AnyObject], statusCode: FlickrClientErrorCodes)
            {
                completionHandler(nil, NSError(domain: "FlickrClient.imagesNearLatitude", code: statusCode.rawValue, userInfo: userInfo))
            }
            
            guard error == nil else {
                completionHandler(nil, error!)
                return
            }
            guard let parsedData = parsedData as? [String: AnyObject] else {
                sendError([NSLocalizedDescriptionKey: "Could not format returned data in to the required format"], statusCode: .JSONParse)
                return
            }
            guard let jsonPhotos = parsedData[Constants.ResponseKeys.Photos] as? [String: AnyObject] else {
                sendError([NSLocalizedDescriptionKey: "Key \(Constants.ResponseKeys.Photos) not found"], statusCode: .KeyNotFound)
                return
            }
            
            let photos: FlickrPhotos
            do {
                photos = try FlickrPhotos(parsedJSON: jsonPhotos, imageSize: .Medium)
            }
            catch let parseError as NSError {
                sendError([NSLocalizedDescriptionKey: "Unable to parse JSON object", NSUnderlyingErrorKey: parseError], statusCode: .KeyNotFound)
                return
            }
            
            completionHandler(photos, nil)
            
        }
        task.resume()
        return task
    }

}
