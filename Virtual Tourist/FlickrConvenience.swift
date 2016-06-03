//
//  FlickrConvenience.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 02/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import UIKit

extension FlickrClient
{
    func taskForGETRequest(parameters: [String: AnyObject], completionHandler: (AnyObject?, NSError?) -> Void) -> NSURLSessionDataTask
    {
        let url = buildURLWithParameters(parameters)
        let task = sharedSession.dataTaskWithURL(url) { (data, response, error) in
            func sendError(userInfo: [String: AnyObject], statusCode: FlickrClientErrorCodes)
            {
                completionHandler(nil, NSError(domain: "FlickrConvenience.taskForGETRequest", code: statusCode.rawValue, userInfo: userInfo))
            }
            
            guard error == nil else {
                completionHandler(nil, error!)
                return
            }
            guard let data = data else {
                sendError([NSLocalizedDescriptionKey: "No data returned by request"], statusCode: .NoData)
                return
            }
            let statusCode = (response as! NSHTTPURLResponse).statusCode
            guard statusCode ~= 200 ..< 300 else {
                sendError([NSLocalizedDescriptionKey: "Bad status code received: \(statusCode)"], statusCode: .BadStatusCode)
                return
            }
            
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            }
            catch let error as NSError {
                parsedResult = nil
                sendError([NSLocalizedDescriptionKey: "Unable to parse JSON object", NSUnderlyingErrorKey: error], statusCode: .JSONParse)
                return
            }
            completionHandler(parsedResult, nil)
        }
        return task
    }
    
    private func buildURLWithParameters(parameters: [String: AnyObject]) -> NSURL
    {
        let url = NSURLComponents()
        url.scheme = Constants.API.Scheme
        url.host = Constants.API.Host
        url.path = Constants.API.Path

        url.queryItems = parameters.map { NSURLQueryItem(name: $0, value: "\($1)") }
        url.queryItems!.append(NSURLQueryItem(name: Constants.ParameterKeys.APIKey, value: Constants.API.Key))
        url.queryItems!.append(NSURLQueryItem(name: Constants.ParameterKeys.NoJSONCallback, value: Constants.ParameterValues.NoJSONCallbackOn))
        url.queryItems!.append(NSURLQueryItem(name: Constants.ParameterKeys.Format, value: Constants.ParameterValues.JSONFormat))
        
        return url.URL!
    }
}
