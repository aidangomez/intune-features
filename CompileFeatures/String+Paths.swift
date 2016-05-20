// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation

extension String {
    mutating func appendPathComponent(component: String) {
        let strippedComponent: String
        if let first = component.characters.first where first == "/" {
            strippedComponent = component.substringFromIndex(component.startIndex.advancedBy(1))
        } else {
            strippedComponent = component
        }
        
        if let last = self.characters.last where last == "/" {
            self += strippedComponent
        } else {
            self += "/" + strippedComponent
        }
    }

    var lastPathComponent: String {
        return (self as NSString).lastPathComponent
    }

    func stringByDeletingLastPathComponent(newExtension: String) -> String {
        return (self as NSString).stringByDeletingLastPathComponent
    }

    func stringByReplacingExtensionWith(newExtension: String) -> String {
        let noExtension: NSString = (self as NSString).stringByDeletingPathExtension
        return noExtension.stringByAppendingPathExtension(newExtension)!
    }

    func stringByAppendingPathComponent(component: String) -> String {
        return (self as NSString).stringByAppendingPathComponent(component)
    }

}

func buildPathFromParts(parts: [String]) -> String {
    guard var path = parts.first else {
        return ""
    }
    
    for part in parts[1..<parts.count] {
        path.appendPathComponent(part)
    }
    return path
}
