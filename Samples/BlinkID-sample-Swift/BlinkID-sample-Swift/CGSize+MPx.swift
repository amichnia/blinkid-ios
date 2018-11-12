//
//  CGSize+MPx.swift
//  Core
//
//  Created by Andrzej Michnia on 30/05/2018.
//  Copyright © 2018 Digidentity. All rights reserved.
//

import Foundation
import CoreGraphics

public extension CGFloat {
    public static var pixel: CGFloat = 1
    public static var megaPixel = CGFloat.pixel * 1000000

    /// MegaPixel value, where 1 million pixels == 1 Mpx
    var megaPixels: CGFloat { return self * CGFloat.megaPixel }
}

public extension Double {
    var megaPixels: CGFloat { return CGFloat(self).megaPixels }
}

public extension Int {
    var megaPixels: CGFloat { return CGFloat(self).megaPixels }
}

public extension CGSize {
    /// Megapixels count in area
    public var mpx: CGFloat {
        return px / CGFloat.megaPixel
    }
    /// Pixels count in area
    public var px: CGFloat {
        return width * height
    }

    /// Biggest size possible, that will fit under given pixels count
    ///
    /// - Parameter pixels: How many pixels should area have (Cane use for example 2.megaPixels)
    /// - Returns: Size that will fit criteria
    public func constrained(to pixels: CGFloat) -> CGSize {
        guard self.px > pixels else { return self }
        guard height != 0 else { return self }

        let scaleSquared = pixels / self.px
        let scale = sqrt(scaleSquared)

        return CGSize(width: floor(width * scale), height: floor(height * scale))
    }
}
