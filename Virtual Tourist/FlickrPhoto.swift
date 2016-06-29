//
//  FlickrPhoto.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 02/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation

enum FlickrPhotoErrorCodes: Int
{
    case IDNotFound
    case URLNotFound
}

class FlickrPhoto
{
    static let idKey = "id"
    
    var id: Int
    var url: NSURL
    
    init?(parsedJSON: [String: AnyObject], imageSize: FlickrImageSize) throws
    {
        func makeError(errorString: String, code: FlickrPhotoErrorCodes) -> NSError
        {
            return NSError(domain: "FlickrPhoto.init", code: code.rawValue,
                            userInfo: [NSLocalizedDescriptionKey: errorString])
        }
        
        guard let id = Int((parsedJSON[FlickrPhoto.idKey] as? String ?? "")) else {
            throw makeError("Key \"\(FlickrPhoto.idKey)\" not found", code: .IDNotFound)
        }
        let urlKey = imageSize.description
        let url: String
        if let parsedURL = parsedJSON[urlKey] as? String {
            url = parsedURL
        }
        else if let parsedURL = parsedJSON[FlickrImageSize.Small.description] as? String {
            url = parsedURL
        }
        else {
            NSLog("Key \"\(urlKey)\" not found")
            return nil
        }
        
        self.id = id
        self.url = NSURL(string: url)!
    }
    
    static func photoArrayFromJSON(parsedJson: [[String: AnyObject]],
        imageSize: FlickrImageSize) throws -> [FlickrPhoto]
    {
        return try parsedJson.flatMap { try FlickrPhoto(parsedJSON: $0, imageSize: imageSize) }
    }
}