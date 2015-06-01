//
//  Logger.swift
//  TimerPeri
//
//  Created by Jay Tucker on 5/28/15.
//  Copyright (c) 2015 Imprivata. All rights reserved.
//

import Foundation

func timestamp() -> String {
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss.SSS"
    return dateFormatter.stringFromDate(NSDate())
}

func log(message: String) {
    println("[\(timestamp())] \(message)")
}
