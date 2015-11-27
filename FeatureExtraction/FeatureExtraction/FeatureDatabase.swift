//  Copyright © 2015 Venture Media. All rights reserved.

import HDF5Kit
import Upsurge

public class FeatureDatabase {
    let chunkSize = 1024
    let filePath: String
    let file: File

    let doubleDatasetSpecs = [
        (name: "peak_locations", size: FeatureBuilder.bandNotes.count),
        (name: "peak_heights", size: FeatureBuilder.bandNotes.count),
        (name: "spectrum", size: FeatureBuilder.bandNotes.count),
        (name: "spectrum_flux", size: FeatureBuilder.bandNotes.count)
    ]
    let intDatasetSpecs = [
        (name: "label", size: FeatureBuilder.bandNotes.count),
        (name: "offset", size: 1),
    ]
    let stringDatasetSpecs = [
        (name: "fileName"),
        (name: "folder"),
    ]

    public struct DoubleTable {
        public var name: String
        public var size: Int
        public var data: RealArray
    }

    public struct IntTable {
        public var name: String
        public var size: Int
        public var data: [Int]
    }

    public struct StringTable {
        public var name: String
        public var data: [String]
    }

    public var doubleTables = [DoubleTable]()
    public var intTables = [IntTable]()
    public var stringTables = [StringTable]()

    public internal(set) var folders = [String]()
    public internal(set) var exampleCount = 0

    var pendingFeatures = [FeatureData]()

    public init(filePath: String, overwrite: Bool) {
        self.filePath = filePath

        if overwrite {
            file = File.create(filePath, mode: .Truncate)!
            create()
        } else if let file = File.open(filePath, mode: .ReadWrite) {
            self.file = file
            load()
        } else {
            file = File.create(filePath, mode: .Exclusive)!
            create()
        }
    }

    func create() {
        for (name, size) in doubleDatasetSpecs {
            let space = Dataspace(dims: [0, size], maxDims: [-1, size])
            file.createDataset(name, type: Double.self, dataspace: space, chunkDimensions: [chunkSize, size])!
            let table = DoubleTable(name: name, size: size, data: RealArray(count: chunkSize * size))
            doubleTables.append(table)
        }
        for (name, size) in intDatasetSpecs {
            let space = Dataspace(dims: [0, size], maxDims: [-1, size])
            file.createDataset(name, type: Int.self, dataspace: space, chunkDimensions: [chunkSize, size])!
            let table = IntTable(name: name, size: size, data: [Int](count: chunkSize * size, repeatedValue: 0))
            intTables.append(table)
        }
        for name in stringDatasetSpecs {
            let space = Dataspace(dims: [0], maxDims: [-1])
            file.createDataset(name, type: String.self, dataspace: space, chunkDimensions: [chunkSize])!
            let table = StringTable(name: name, data: [String](count: chunkSize, repeatedValue: ""))
            stringTables.append(table)
        }
    }

    func load() {
        for (name, size) in doubleDatasetSpecs {
            guard let dataset = file.openDataset(name, type: Double.self) else {
                preconditionFailure("Existing file doesn't have a \(name) dataset")
            }

            guard let nativeType = dataset.type.nativeType else {
                preconditionFailure("Existing dataset '\(name)' is not of a native data type")
            }
            precondition(nativeType == .Double, "Existing dataset '\(name)' is of the wrong type")

            let dims = dataset.space.dims
            precondition(dims.count == 2 && dims[1] == size, "Existing dataset '\(name)' is of the wrong size")
            exampleCount = dims[0]
            
            let table = DoubleTable(name: name, size: size, data: RealArray(count: size * chunkSize))
            doubleTables.append(table)
        }
        for (name, size) in intDatasetSpecs {
            guard let dataset = file.openDataset(name, type: Int.self) else {
                preconditionFailure("Existing file doesn't have a \(name) dataset")
            }

            guard let nativeType = dataset.type.nativeType else {
                preconditionFailure("Existing dataset '\(name)' is not of a native data type")
            }
            precondition(nativeType == .Int, "Existing dataset '\(name)' is of the wrong type")

            let dims = dataset.space.dims
            precondition(dims.count == 2 && dims[1] == size, "Existing dataset '\(name)' is of the wrong size")

            let table = IntTable(name: name, size: size, data: [Int](count: size * chunkSize, repeatedValue: 0))
            intTables.append(table)
        }
        for name in stringDatasetSpecs {
            guard let dataset = file.openDataset(name, type: String.self) else {
                preconditionFailure("Existing file doesn't have a \(name) dataset")
            }

            let dims = dataset.space.dims
            precondition(dims.count == 1, "Existing dataset '\(name)' is of the wrong size")

            let table = StringTable(name: name, data: [String](count: chunkSize, repeatedValue: ""))
            stringTables.append(table)
        }

        guard let foldersDataset = file.openDataset("folder", type: Double.self) else {
            preconditionFailure("Existing file doesn't have a folder dataset")
        }
        folders = foldersDataset.readString()
    }
    
    public func getDoubleTable(name: String) -> DoubleTable? {
        for table in doubleTables {
            if table.name == name {
                return table
            }
        }
        return nil
    }
    
    public func readDoubleTableData(table: DoubleTable, index: Int) -> RealArray {
        guard let dataset = file.openDataset(table.name, type: Double.self) else {
            preconditionFailure("Existing file doesn't have a \(table.name) dataset")
        }
        
        let data = RealArray(count: table.size)
        
        let fileSpace = Dataspace(dataset.space)
        let selection = HyperslabIndex(start: 0, count: table.size)
        fileSpace.select(index, selection)
        
        let memSpace = Dataspace(dims: [1, table.size])
        dataset.readDouble(data.mutablePointer, memSpace: memSpace, fileSpace: fileSpace)

        return data
    }
    
    public func getIntTable(name: String) -> IntTable? {
        for table in intTables {
            if table.name == name {
                return table
            }
        }
        return nil
    }
    
    public func readIntTableData(table: IntTable, index: Int) -> [Int] {
        guard let dataset = file.openDataset(table.name, type: Int.self) else {
            preconditionFailure("Existing file doesn't have a \(table.name) dataset")
        }
        
        var data = [Int](count: table.size, repeatedValue: 0)
        
        let fileSpace = Dataspace(dataset.space)
        let selection = HyperslabIndex(start: 0, count: table.size)
        fileSpace.select(index, selection)
        
        let memSpace = Dataspace(dims: [1, table.size])
        dataset.readInt(&data, memSpace: memSpace, fileSpace: fileSpace)
        
        return data
    }
    
    public func getStringTable(name: String) -> StringTable? {
        for table in stringTables {
            if table.name == name {
                return table
            }
        }
        return nil
    }
    
    public func readStringTableData(table: StringTable, index: Int) -> String {
        guard let dataset = file.openDataset(table.name, type: Double.self) else {
            preconditionFailure("Existing file doesn't have a \(table.name) dataset")
        }
        
        let space = Dataspace(dataset.space)
        space.select(index)
        return dataset.readString(fileSpace: space)[0]
    }

    public func appendFeatures(features: [FeatureData], folder: String?) {
        var offset = 0

        if pendingFeatures.count > 0 {
            let missing = chunkSize - pendingFeatures.count
            offset = min(missing, features.count)
            pendingFeatures += features[0..<offset]
            if pendingFeatures.count < chunkSize {
                // Not enough data for a full chunk
                return
            }
        }

        if pendingFeatures.count == chunkSize {
            appendChunk(ArraySlice(pendingFeatures))
            pendingFeatures.removeAll(keepCapacity: true)
        }

        while features.count - offset >= chunkSize {
            appendChunk(features[offset..<offset + chunkSize])
            offset += chunkSize
        }

        pendingFeatures += features[offset..<features.count]

        if let folder = folder {
            let foldersTable = stringTables.filter({ $0.name == "folder" }).first!
            appendFolder(folder, forTable: foldersTable)
        }

        file.flush()
    }

    func appendChunk(features: ArraySlice<FeatureData>) {
        assert(features.count == chunkSize)

        for table in doubleTables {
            appendDoubleChunk(features, forTable: table)
        }

        let labelsTable = intTables.filter({ $0.name == "label" }).first!
        appendLabelsChunk(features, forTable: labelsTable)

        let offsetsTable = intTables.filter({ $0.name == "offset" }).first!
        appendOffsetsChunk(features, forTable: offsetsTable)

        let fileNamesTable = stringTables.filter({ $0.name == "fileName" }).first!
        appendFileNamesChunk(features, forTable: fileNamesTable)

        exampleCount += features.count
    }

    func appendDoubleChunk(features: ArraySlice<FeatureData>, forTable table: DoubleTable) {
        guard let dataset = file.openDataset(table.name, type: Double.self) else {
            preconditionFailure("Existing file doesn't have a \(table.name) dataset")
        }

        let currentSize = dataset.extent[0]
        dataset.extent[0] += chunkSize

        let filespace = dataset.space
        filespace.select(start: [currentSize, 0], stride: nil, count: [chunkSize, table.size], block: nil)

        assert(table.data.capacity == chunkSize * table.size)
        table.data.count = 0
        let memspace = Dataspace(dims: [chunkSize, table.size])

        for featureData in features {
            guard let data = featureData.features[table.name] else {
                fatalError("Feature is missing dataset \(table.name)")
            }
            table.data.appendContentsOf(data)
        }

        if !dataset.writeDouble(table.data.pointer, memSpace: memspace, fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }

    func appendLabelsChunk(features: ArraySlice<FeatureData>, var forTable table: IntTable) {
        guard let dataset = file.openDataset(table.name, type: Int.self) else {
            preconditionFailure("Existing file doesn't have a \(table.name) dataset")
        }

        let currentSize = dataset.extent[0]
        dataset.extent[0] += chunkSize

        let filespace = dataset.space
        filespace.select(start: [currentSize, 0], stride: nil, count: [chunkSize, table.size], block: nil)

        table.data.removeAll(keepCapacity: true)
        let memspace = Dataspace(dims: [chunkSize, table.size])

        for feature in features {
            table.data.appendContentsOf(feature.example.label)
        }
        if !dataset.writeInt(table.data.pointer, memSpace: memspace, fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }

    func appendOffsetsChunk(features: ArraySlice<FeatureData>, var forTable table: IntTable) {
        guard let dataset = file.openDataset(table.name, type: Int.self) else {
            preconditionFailure("Existing file doesn't have a \(table.name) dataset")
        }

        let currentSize = dataset.extent[0]
        dataset.extent[0] += chunkSize

        let filespace = dataset.space
        filespace.select(start: [currentSize, 0], stride: nil, count: [chunkSize, table.size], block: nil)

        table.data.removeAll(keepCapacity: true)
        let memspace = Dataspace(dims: [chunkSize, table.size])

        for feature in features {
            table.data.append(feature.example.frameOffset)
        }
        if !dataset.writeInt(table.data.pointer, memSpace: memspace, fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }

    func appendFileNamesChunk(features: ArraySlice<FeatureData>, var forTable table: StringTable) {
        guard let dataset = file.openDataset(table.name, type: String.self) else {
            preconditionFailure("Existing file doesn't have a \(table.name) dataset")
        }

        let currentSize = dataset.extent[0]
        dataset.extent[0] += chunkSize

        let filespace = dataset.space
        filespace.select(start: [currentSize], stride: nil, count: [chunkSize], block: nil)

        table.data.removeAll(keepCapacity: true)

        for feature in features {
            table.data.append(feature.example.filePath)
        }
        if !dataset.writeString(table.data, fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }

    func appendFolder(folder: String, var forTable table: StringTable) {
        guard let dataset = file.openDataset(table.name, type: String.self) else {
            preconditionFailure("Existing file doesn't have a \(table.name) dataset")
        }

        folders.append(folder)

        let currentSize = dataset.extent[0]
        dataset.extent[0] += 1

        let filespace = dataset.space
        filespace.select(start: [currentSize], stride: nil, count: [1], block: nil)

        table.data.removeAll(keepCapacity: true)

        table.data.append(folder)
        if !dataset.writeString(table.data, fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }

    public func shuffle(chunkSize chunkSize: Int, passes: Int = 1, progress: (Double -> Void)? = nil) {
        let shuffleCount = passes * exampleCount / chunkSize
        for i in 0..<shuffleCount {
            let start1 = i * chunkSize % (exampleCount - chunkSize + 1)
            let start2 = randomInRange(0...exampleCount - chunkSize)
            let indices = (0..<2*chunkSize).shuffle()

            shuffleDoubleTables(chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)
            shuffleIntTables(chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)
            shuffleStringTables(chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)

            file.flush()
            progress?(Double(i) / Double(shuffleCount - 1))
        }
        file.flush()
    }

    func shuffleDoubleTables(chunkSize chunkSize: Int, start1: Int, start2: Int, indices: [Int]) {
        var data = [Double](count: 2*chunkSize*FeatureBuilder.bandNotes.count, repeatedValue: 0)
        for table in doubleTables {
            guard let dataset = file.openDataset(table.name, type: Double.self) else {
                preconditionFailure("Existing file doesn't have a \(table.name) dataset")
            }

            let memspace1 = Dataspace(dims: [2*chunkSize, table.size])
            memspace1.select(start: [0, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            let filespace1 = Dataspace(dataset.space)
            filespace1.select(start: [start1, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            assert(data.count >= memspace1.selectionSize)
            dataset.readDouble(&data, memSpace: memspace1, fileSpace: filespace1)

            let memspace2 = Dataspace(dims: [2*chunkSize, table.size])
            memspace2.select(start: [chunkSize, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            let filespace2 = Dataspace(dataset.space)
            filespace2.select(start: [start2, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            assert(data.count - chunkSize >= memspace1.selectionSize)
            dataset.readDouble(&data, memSpace: memspace2, fileSpace: filespace2)

            for i in 0..<2*chunkSize {
                let index = indices[i]
                if index != i {
                    swap(&data[i], &data[index])
                }
            }

            dataset.writeDouble(data, memSpace: memspace1, fileSpace: filespace1)
            dataset.writeDouble(data, memSpace: memspace2, fileSpace: filespace2)
        }
    }

    func shuffleIntTables(chunkSize chunkSize: Int, start1: Int, start2: Int, indices: [Int]) {
        var data = [Int](count: 2*chunkSize*FeatureBuilder.bandNotes.count, repeatedValue: 0)
        for table in intTables {
            guard let dataset = file.openDataset(table.name, type: Int.self) else {
                preconditionFailure("Existing file doesn't have a \(table.name) dataset")
            }

            let memspace1 = Dataspace(dims: [2*chunkSize, table.size])
            memspace1.select(start: [0, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            let filespace1 = Dataspace(dataset.space)
            filespace1.select(start: [start1, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            assert(data.count >= memspace1.selectionSize)
            dataset.readInt(&data, memSpace: memspace1, fileSpace: filespace1)

            let memspace2 = Dataspace(dims: [2*chunkSize, table.size])
            memspace2.select(start: [chunkSize, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            let filespace2 = Dataspace(dataset.space)
            filespace2.select(start: [start2, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            assert(data.count - chunkSize >= memspace1.selectionSize)
            dataset.readInt(&data, memSpace: memspace2, fileSpace: filespace2)

            for i in 0..<2*chunkSize {
                let index = indices[i]
                if index != i {
                    swap(&data[i], &data[index])
                }
            }

            dataset.writeInt(data, memSpace: memspace1, fileSpace: filespace1)
            dataset.writeInt(data, memSpace: memspace2, fileSpace: filespace2)
        }
    }

    func shuffleStringTables(chunkSize chunkSize: Int, start1: Int, start2: Int, indices: [Int]) {
        for table in stringTables {
            if table.name == "folder" {
                continue
            }

            guard let dataset = file.openDataset(table.name, type: String.self) else {
                preconditionFailure("Existing file doesn't have a \(table.name) dataset")
            }

            let filespace1 = Dataspace(dataset.space)
            filespace1.select(start: [start1, 0], stride: nil, count: [chunkSize], block: nil)
            var strings1 = dataset.readString(fileSpace: filespace1)
            assert(strings1.count == filespace1.selectionSize)

            let filespace2 = Dataspace(dataset.space)
            filespace2.select(start: [start2, 0], stride: nil, count: [chunkSize], block: nil)
            var strings2 = dataset.readString(fileSpace: filespace2)
            assert(strings2.count == filespace2.selectionSize)

            var strings = strings1 + strings2

            for i in 0..<2*chunkSize {
                let index = indices[i]
                if index != i {
                    swap(&strings[i], &strings[index])
                }
            }

            strings1 = [String](strings.dropLast(chunkSize))
            strings2 = [String](strings.dropFirst(chunkSize))
            dataset.writeString(strings1, fileSpace: filespace1)
            dataset.writeString(strings2, fileSpace: filespace2)
        }
    }
}
