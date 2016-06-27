//
//  FlickrURL.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 13/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation

class FlickrURL
{
    let url: NSURL
    
    init(parameters: [String: AnyObject])
    {
        let url = NSURLComponents()
        url.scheme = Constants.API.Scheme
        url.host = Constants.API.Host
        url.path = Constants.API.Path
        
        url.queryItems = parameters.map { NSURLQueryItem(name: $0, value: "\($1)") }
        url.queryItems!.append(NSURLQueryItem(name: Constants.ParameterKeys.APIKey, value: Constants.API.Key))
        url.queryItems!.append(NSURLQueryItem(name: Constants.ParameterKeys.NoJSONCallback,
            value: Constants.ParameterValues.NoJSONCallbackOn))
        url.queryItems!.append(NSURLQueryItem(name: Constants.ParameterKeys.Format,
            value: Constants.ParameterValues.JSONFormat))
        
        self.url = url.URL!
    }
}