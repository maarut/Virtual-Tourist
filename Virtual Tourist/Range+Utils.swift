//
//  Range+Utils.swift
//  Virtual Tourist
//
//  Created by Maarut Chandegra on 02/06/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

// Basic function to make a range match more readable in an `if` or `where` clause.
// Ie. write `value ~= range` (value is in range) as opposed to `range ~= value` (range contains value)
// It looks more natural to read `if value ~= 0 ..< 100 {...` than `if 0 ..< 100 ~= value {...`
public func ~=<I : ForwardIndexType where I : Comparable>(value: I, pattern: Range<I>) -> Bool
{
    return pattern ~= value
}