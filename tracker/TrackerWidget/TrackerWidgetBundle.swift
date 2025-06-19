import WidgetKit
import SwiftUI

@main
struct TrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrackerWidget()
        TrackerWidgetControl()
    }
}
