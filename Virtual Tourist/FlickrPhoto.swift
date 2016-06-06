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
    static let baseUrlKey = "url_"
    
    var id: Int
    var url: NSURL
    
    init(parsedJSON: [String: AnyObject], imageSize: FlickrClient.FlickrImageSize) throws
    {
        func makeError(errorString: String, code: FlickrPhotoErrorCodes) -> NSError
        {
            return NSError(domain: "FlickrPhoto.init", code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: errorString])
        }
        
        guard let id = Int((parsedJSON[FlickrPhoto.idKey] as? String ?? "")) else {
            throw makeError("Key \"\(FlickrPhoto.idKey)\" not found", code: .IDNotFound)
        }
        let urlKey = FlickrClient.parameterValueForImageSize(imageSize)
        guard let url = parsedJSON[urlKey] as? String else {
            throw makeError("Key \"\(urlKey)\" not found", code: .URLNotFound)
        }
        
        self.id = id
        self.url = NSURL(string: url)!
    }
    
    static func photoArrayFromJSON(parsedJson: [[String: AnyObject]], imageSize: FlickrClient.FlickrImageSize) throws -> [FlickrPhoto]
    {
        var parsedPhotos = [FlickrPhoto]()
        for photo in parsedJson {
            try parsedPhotos.append(FlickrPhoto(parsedJSON: photo, imageSize: imageSize))
        }
        return parsedPhotos
    }
}