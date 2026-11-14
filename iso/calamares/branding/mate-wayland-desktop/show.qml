import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation
    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 20
            text: "Installing MATE Wayland Desktop.\n\nThe MATE desktop on Wayland, using the labwc compositor."
        }
    }
}
