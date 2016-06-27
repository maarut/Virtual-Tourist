//
//  FlickrImageSearch.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 13/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation
import CoreData

struct FlickrImageSearchCriteria
{
    let longitude: Double
    let latitude: Double
    let limit: Int
    let searchResultPageNumber: Int
}

enum FlickrClientErrorCodes: Int
{
    case NoData
    case JSONParse
    case KeyNotFound
}

class FlickrImageSearch: FlickrNetworkOperationProcessor
{
    private let pin: Pin
    
    private let _request: NSURLRequest
    var request: NSURLRequest {
        get {
            return _request
        }
    }
    
    init(criteria: FlickrImageSearchCriteria, insertResultsInto pin: Pin)
    {
        let parameters: [String: AnyObject] = [
            Constants.ParameterKeys.Method: "flickr.photos.search",
            Constants.ParameterKeys.Extras: stringOf([FlickrImageSize.Medium, .Small]),
            Constants.ParameterKeys.Longitude: criteria.longitude,
            Constants.ParameterKeys.Latitude: criteria.latitude,
            Constants.ParameterKeys.SafeSearch: Constants.ParameterValues.SafeSearchOn,
            Constants.ParameterKeys.PerPageLimit: criteria.limit,
            Constants.ParameterKeys.Page: criteria.searchResultPageNumber
        ]
        _request = NSURLRequest(URL: FlickrURL(parameters: parameters).url)
        self.pin = pin
    }
    
    func processData(data: NSData)
    {
        guard let parsedJSON = parseJSON(data) else { return }
        guard let parsedData = parsedJSON as? [String: AnyObject] else {
            
            let userInfo = [NSLocalizedDescriptionKey: "Could not format returned data in to the required format"]
            let error = NSError(domain: "FlickrImageSearch.processData",
                                code: FlickrClientErrorCodes.JSONParse.rawValue, userInfo: userInfo)
            handleError(error)
            return
        }
        
        guard let jsonPhotos = parsedData[Constants.ResponseKeys.Photos] as? [String: AnyObject] else {
            let userInfo = [NSLocalizedDescriptionKey: "Key \(Constants.ResponseKeys.Photos) not found"]
            let error = NSError(domain: "FlickrImageSearch.processData",
                code: FlickrClientErrorCodes.KeyNotFound.rawValue, userInfo: userInfo)
            handleError(error)
            return
        }
        
        guard let photos = parseFlickrPhotosFrom(jsonPhotos) else { return }
        
        pin.photoContainer = createPhotoContainerFrom(photos)
        saveContext()
    }
    
    private func saveContext()
    {
        pin.managedObjectContext?.performBlock {
            if self.pin.managedObjectContext!.hasChanges {
                do {
                    try self.pin.managedObjectContext!.save()
                }
                catch let error as NSError {
                    NSLog("\(error.description)\n\(error.localizedDescription)")
                }
            }
        }
    }
    
    private func createPhotoContainerFrom(photos: FlickrPhotos) -> PhotoContainer
    {
        let photoContainer = PhotoContainer(context: pin.managedObjectContext!, pin: pin)
        photoContainer.page = photos.page
        photoContainer.pageCount = photos.pages
        photoContainer.total = photos.total
        photoContainer.perPage = photos.perPage
        let photoArray = photos.photos.map {
            Photo(context: pin.managedObjectContext!, id: $0.id, url: $0.url.absoluteString)
        }
        photoContainer.photos = NSOrderedSet(array: photoArray)
        return photoContainer
    }
    
    private func parseFlickrPhotosFrom(json: [String: AnyObject]) -> FlickrPhotos?
    {
        let photos: FlickrPhotos?
        do {
            photos = try FlickrPhotos(parsedJSON: json, imageSize: .Medium)
        }
        catch let parseError as NSError {
            photos = nil
            let userInfo = [NSLocalizedDescriptionKey: "Unable to parse JSON object", NSUnderlyingErrorKey: parseError]
            let error = NSError(domain: "FlickrImageSearch.processData",
                                code: FlickrClientErrorCodes.KeyNotFound.rawValue, userInfo: userInfo)
            handleError(error)
        }
        return photos
    }
    
    private func parseJSON(data: NSData) -> AnyObject?
    {
        let parsedResult: AnyObject?
        do {
            parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
        }
        catch let error as NSError {
            parsedResult = nil
            let userInfo = [NSLocalizedDescriptionKey: "Unable to parse JSON object", NSUnderlyingErrorKey: error]
            let error = NSError(domain: "FlickrImageSearch.parseJSON", code: FlickrClientErrorCodes.JSONParse.rawValue,
                userInfo: userInfo)
            handleError(error)
        }
        return parsedResult
    }
    
    func handleError(error: NSError)
    {
        //TODO: Implement error handling logic
    }
}