//
//  HUDWidgetExtensionBundle.swift
//  HUDWidgetExtension
//
//  Created by Omari Bell on 10/2/26.
//

import WidgetKit
import SwiftUI

@main
struct HUDWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        HUDWidgetExtension()
        HUDWidgetExtensionControl()
        HUDWidgetExtensionLiveActivity()
    }
}
