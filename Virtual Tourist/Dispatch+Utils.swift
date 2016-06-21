//
//  Dispatch+utils.swift
//  On The Map
//
//  Created by Maarut Chandegra on 15/05/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import Foundation

func after(time: dispatch_time_t,
            onQueue queue: dispatch_queue_t = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            do block: () -> Void)
{
    dispatch_after(time, queue, block)
}

func onMainQueueDo(block: () -> Void)
{
    dispatch_async(dispatch_get_main_queue(), block)
}

extension Int64
{
    func seconds() -> dispatch_time_t
    {
        return dispatch_time(DISPATCH_TIME_NOW, Int64(UInt64(self) * NSEC_PER_SEC))
    }
}
