//
//  Array+utils.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 08/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation

extension Array
{
    public func first(@noescape predicate: (Element) -> Bool) -> Element?
    {
        for e in self {
            if predicate(e) { return e }
        }
        return nil
    }
}