//
//  FlickrPhotos.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 02/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation

enum FlickrPhotosErrorCodes: Int
{
    case PageKeyNotFound
    case PagesKeyNotFound
    case PerPageKeyNotFound
    case TotalKeyNotFound
    case PhotoKeyNotFound
}

class FlickrPhotos
{
    static let pageKey = "page"
    static let pagesKey = "pages"
    static let perPageKey = "perpage"
    static let totalKey = "total"
    static let photoArrayKey = "photo"
    
    var page: Int
    var pages: Int
    var perPage: Int
    var total: Int
    var photos: [FlickrPhoto]
    
    init(parsedJSON: [String: AnyObject], imageSize: FlickrImageSize) throws
    {
        func makeError(errorString: String, code: FlickrPhotosErrorCodes) -> NSError
        {
            return NSError(domain: "FlickrPhotos.init", code: code.rawValue,
                            userInfo: [NSLocalizedDescriptionKey: errorString])
        }
        
        guard let page = parsedJSON[FlickrPhotos.pageKey] as? Int else {
            throw makeError("Key \"\(FlickrPhotos.pageKey)\" not found", code: .PageKeyNotFound)
        }
        guard let pages = parsedJSON[FlickrPhotos.pagesKey] as? Int else {
            throw makeError("Key \"\(FlickrPhotos.pagesKey)\" not found", code: .PagesKeyNotFound)
        }
        guard let perPage = parsedJSON[FlickrPhotos.perPageKey] as? Int else {
            throw makeError("Key \"\(FlickrPhotos.perPageKey)\" not found", code: .PerPageKeyNotFound)
        }
        guard let total = Int(parsedJSON[FlickrPhotos.totalKey] as? String ?? "") else {
            throw makeError("Key \"\(FlickrPhotos.totalKey)\" not found", code: .TotalKeyNotFound)
        }
        guard let photoArray = parsedJSON[FlickrPhotos.photoArrayKey] as? [[String: AnyObject]] else {
            throw makeError("Key \"\(FlickrPhotos.photoArrayKey)\" not found", code: .PhotoKeyNotFound)
        }
        self.page = page
        self.pages = pages
        self.perPage = perPage
        self.total = total
        self.photos = try FlickrPhoto.photoArrayFromJSON(photoArray, imageSize: imageSize)
    }
}