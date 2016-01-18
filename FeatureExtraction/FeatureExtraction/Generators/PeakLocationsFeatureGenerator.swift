//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class PeakLocationsFeatureGenerator : BandsFeatureGenerator {
    public var peakLocations: RealArray

    public override var data: RealArray {
        return peakLocations
    }
    
    public override init(notes: Range<Int>, bandSize: Double) {
        peakLocations = RealArray(count: notes.count)
        super.init(notes: notes, bandSize: bandSize)
    }

    public func update(peaks: [Point]) {
        let bandCount = notes.count
        
        var peaksByBand = [Int: Point]()
        for peak in peaks {
            let note = freqToNote(peak.x)
            let band = bandForNote(note)
            guard band >= 0 && band < bandCount else {
                continue
            }

            if let existingPeak = peaksByBand[band] {
                if existingPeak.y < peak.y {
                    peaksByBand[band] = peak
                }
            } else {
                peaksByBand[band] = peak
            }
        }

        for band in 0..<bandCount {
            let note = noteForBand(band)
            if let peak = peaksByBand[band] {
                let peakN = freqToNote(peak.x)
                peakLocations[band] = 1.0 - abs(note - peakN)
            } else {
                peakLocations[band] = 0.0
            }
        }
    }
}
