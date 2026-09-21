import QtQuick 2.5
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 22
            color: "#f2f4f7"
            text: "Master Penguin Linux\n\nUbuntu underneath, with the parts you do not need left out."
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 22
            color: "#f2f4f7"
            text: "apt, snap and flatpak all work.\nThe Software app can install from any of them."
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 22
            color: "#f2f4f7"
            text: "Thai is set up out of the box:\nfonts, input method and translations."
        }
    }
}
