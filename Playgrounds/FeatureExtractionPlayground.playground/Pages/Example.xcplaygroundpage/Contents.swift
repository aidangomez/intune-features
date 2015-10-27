import FeatureExtraction
import HDF5Kit
import PlotKit
import Upsurge
import XCPlayground

//: ## Parameters
//: Start by selecting the feature and example
let featureName = "bands"
let exampleIndex = 395

//: ## Setup code
//: No need to touch this
func readData(filePath: String, datasetName: String) -> [Double] {
    guard let file = File.open(filePath, mode: .ReadOnly) else {
        fatalError("Failed to open file")
    }

    guard let dataset = file.openDataset(datasetName) else {
        fatalError("Failed to open Dataset")
    }

    let size = Int(dataset.space.size)
    var data = [Double](count: size, repeatedValue: 0.0)
    dataset.readDouble(&data)

    return data
}

let path = testingFeaturesPath()
let labels = readData(path, datasetName: "label")
let featureData = readData(path, datasetName: featureName)

let label = labels[exampleIndex]

//: ## Plotting code
let plot = PlotView(frame: NSRect(origin: CGPointZero, size: plotSize))
plot.addAxis(Axis(orientation: .Horizontal, ticks: .Distance(12)))
plot.addAxis(Axis(orientation: .Vertical))
XCPlaygroundPage.currentPage.liveView = plot

var maxY = 0.0
let exampleCount = labels.count
let exampleSize = featureData.count / exampleCount
let points = (0..<exampleSize).map { featureIndex -> PlotKit.Point in
    let value = featureData[exampleIndex * exampleSize + featureIndex]
    if value > maxY {
        maxY = value
    }
    return PlotKit.Point(x: Double(35 + featureIndex), y: value)
}

let pointSet = PointSet(points: points)
plot.addPointSet(pointSet)

if let note = labelToNote(label) {
    let expectedBand0 = freqToNote(noteToFreq(Double(note)))
    let expectedBand1 = freqToNote(noteToFreq(Double(note)) * 2)
    let expectedBand2 = freqToNote(noteToFreq(Double(note)) * 3)
    let expectedPointSet = PointSet(points: [
        Point(x: expectedBand0, y: 0), Point(x: expectedBand0, y: maxY), Point(x: expectedBand0, y: 0),
        Point(x: expectedBand1, y: 0), Point(x: expectedBand1, y: maxY), Point(x: expectedBand1, y: 0),
        Point(x: expectedBand2, y: 0), Point(x: expectedBand2, y: maxY), Point(x: expectedBand2, y: 0)
    ])
    expectedPointSet.color = NSColor.lightGrayColor()
    plot.addPointSet(expectedPointSet)
}

plot
