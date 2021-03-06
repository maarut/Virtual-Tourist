//
//  FlickrConstants.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 02/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import UIKit

public enum FlickrImageSize: String, CustomStringConvertible
{
    case Small = "url_m"
    case Medium = "url_z"
    case Large = "url_b"
    
    public var description: String {
        get {
            return self.rawValue
        }
    }
}

public func stringOf(array: Array<FlickrImageSize>) -> String
{
    return array.reduce("", combine: { $0.isEmpty ? $1.description : "\($0),\($1)" })
}

struct Constants
{
    struct API
    {
        static let Scheme = "https"
        static let Host = "api.flickr.com"
        static let Path = "/services/rest/"
        static let Key = kFlickrAPIKey
    }
    
    struct ParameterKeys
    {
        static let Method = "method"
        static let APIKey = "api_key"
        static let SafeSearch = "safe_search"
        static let Extras = "extras"
        static let Format = "format"
        static let NoJSONCallback = "nojsoncallback"
        static let Latitude = "lat"
        static let Longitude = "lon"
        static let PerPageLimit = "per_page"
        static let Page = "page"
    }
    
    struct ParameterValues
    {
        static let SafeSearchOn = "1"
        static let JSONFormat = "json"
        static let NoJSONCallbackOn = "1"
    }
    
    struct ResponseKeys
    {
        static let Status = "stat"
        static let Photos = "photos"
    }
    
}