//  Copyright © 2015 Venture Media. All rights reserved.

import UIKit


class ExampleInfoView: UIView {
    @IBOutlet weak var label: UITextField!
    @IBOutlet weak var note: UITextField!
}


class ViewController: UIViewController {
    let net = MonophonicNet()
    let startNote = 36
    
    @IBOutlet weak var exampleStackView: UIStackView!
    @IBOutlet weak var outputStackView: UIStackView!

    @IBOutlet weak var exampleIndexTextField: UITextField!

    @IBOutlet weak var timeTextField: UITextField!

    @IBOutlet weak var allMatchesLabel: UILabel!
    @IBOutlet weak var allMatchesTimeTextField: UITextField!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        run()
    }

    @IBAction func changeIndex(sender: UIStepper) {
        exampleIndexTextField.text = String(format: "%.0f", arguments: [sender.value])
        run()
    }
    
    func update(labels: ArraySlice<Float>) {
        var filterdLabels = [Int]()
        for (index, label) in labels.enumerate() {
            if label == 1 {
                filterdLabels.append(index)
            }
        }
        
        for view in exampleStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        
        for label in filterdLabels {
            let view = NSBundle.mainBundle().loadNibNamed("ExampleInfoView", owner: self, options: nil).first as! ExampleInfoView
            view.label.text = "\(label)"
            view.note.text = "\(label + startNote)"
            exampleStackView.addArrangedSubview(view)
        }
    }

    @IBAction func run() {
        guard let index = Int(exampleIndexTextField.text!) else {
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let labels = net.on_labels[index*60..<index*60+60]
        update(labels)
        
        let result = net.run(index)

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        timeTextField.text = "\(timeElapsed)s"

        var values = [(Int, Double)]()
        for i in 0..<result.count {
            let v = result[i]
            values.append((i, v))
        }

        for view in outputStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        
        let sortedValues = values.sort{ $0.1 > $1.1 }
        for (label, value) in sortedValues {
            let view = NSBundle.mainBundle().loadNibNamed("ExampleInfoView", owner: self, options: nil).first as! ExampleInfoView
            view.label.text = "\(label)"
            view.note.text = "\(value)"
            outputStackView.addArrangedSubview(view)
        }
    }

    @IBAction func runAll() {
        activityIndicator.startAnimating()
        let startTime = CFAbsoluteTimeGetCurrent()
        var stats = Stats(exampleCount: net.on_labels.count)

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
            for index in 0..<stats.exampleCount {
                let label = Int(self.net.on_labels[index])
                let result = self.net.run(index)
                let (match, value) = maxi(result)!
                if match == Int(label) {
                    stats.addMatch(label: label, value: value)
                } else {
                    stats.addMismatch(expectedLabel: label, actualLabel: match, value: value)
                    Swift.print("Mismatch for example \(index). Expected \(label) (\(label + self.startNote)) got \(match) (\(match + self.startNote)) with value \(value).")
                }
            }

            stats.print()

            dispatch_async(dispatch_get_main_queue()) {
                self.updateAllMatches(startTime, stats: stats)
            }
        }
    }

    func updateAllMatches(startTime: CFAbsoluteTime, stats: Stats) {
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let timePerExample = timeElapsed / Double(stats.exampleCount)

        self.allMatchesTimeTextField.text = String(format: "%.3fs – %.3fs/example", arguments: [timeElapsed, timePerExample])

        let percent = stats.accuracy * 100
        self.allMatchesLabel.text = "Matched \(stats.matches) of \(stats.exampleCount) (\(percent)%)"

        self.activityIndicator.stopAnimating()
    }
}
