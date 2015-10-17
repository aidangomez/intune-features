import BrainCore
import HDF5Kit
import Upsurge

//: ## Helper classes and functions

//: Define a DataLayer that returns a static piece of data
class Source : DataLayer {
    var data: Blob
    init(data: Blob) {
        self.data = data
    }
}

//: Define a SinkLayer that stores the last piece of data it got
class Sink : SinkLayer {
    var data: Blob = []
    func consume(input: Blob) {
        data = input
    }
}

//: Define a function to read data from an h5 file
func readData(filePath: String, datasetName: String) -> [Double] {
    guard let file = File.open(filePath, mode: .ReadOnly) else {
        fatalError("Failed to open file")
    }

    guard let dataset = Dataset.open(file: file, name: datasetName) else {
        fatalError("Failed to open Dataset")
    }

    let size = Int(dataset.space.size)
    var data = [Double](count: size, repeatedValue: 0.0)
    dataset.readDouble(&data)

    return data
}


//: ## Network definition
let net = Net()

let source = Source(data: [1, 1])
let ip = InnerProductLayer(inputSize: 2, outputSize: 1)
ip.weights = Matrix<Double>(rows: 2, columns: 1, elements: [2, -4])
ip.biases = [1]
let sink = Sink()

let sourceRef = net.addLayer(source)
let ipRef = net.addLayer(ip)
let reluRef = net.addLayer(ReLULayer(size: 1))
let sinkRef = net.addLayer(sink)

net.connectLayer(sourceRef, toLayer: ipRef)
net.connectLayer(ipRef, toLayer: reluRef)
net.connectLayer(reluRef, toLayer: sinkRef)
net.forward()

sink.data
