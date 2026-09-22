// The slideshow shown while files are being copied.
//
// Every slide used to be #f2f4f7 text, which is near-white, drawn on the
// panel Calamares gives the slideshow -- which is white. The words were on
// the screen the whole time and could not be read. Colours are set here
// rather than inherited, and the background is drawn rather than assumed,
// so the contrast does not depend on which Qt theme the live session picked.
import QtQuick 2.5
import calamares.slideshow 1.0

Presentation {
    id: presentation

    property color paper: "#f4f8fd"
    property color ink:   "#0f2a44"
    property color blue:  "#1668c4"

    Timer {
        interval: 9000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    // The installer defaults to Thai (R-10), so Thai leads and English
    // follows, lighter, for anyone who switched on the first page.

    Slide {
        Rectangle { anchors.fill: parent; color: presentation.paper }
        Column {
            anchors.centerIn: parent
            spacing: 18
            width: parent.width * 0.8

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 30
                font.bold: true
                color: presentation.blue
                wrapMode: Text.WordWrap
                text: "Master Penguin Linux"
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 20
                color: presentation.ink
                wrapMode: Text.WordWrap
                text: "พื้นฐานเป็น Ubuntu แต่ตัดส่วนที่ไม่จำเป็นออก"
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 16
                color: presentation.ink
                opacity: 0.75
                wrapMode: Text.WordWrap
                text: "Ubuntu underneath, with the parts you do not need left out."
            }
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: presentation.paper }
        Column {
            anchors.centerIn: parent
            spacing: 18
            width: parent.width * 0.8

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 30
                font.bold: true
                color: presentation.blue
                wrapMode: Text.WordWrap
                text: "apt · snap · flatpak"
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 20
                color: presentation.ink
                wrapMode: Text.WordWrap
                text: "ใช้ได้ทั้งสามแบบ และติดตั้ง .deb ได้โดยตรง\nแอป Software เลือกให้เองว่าจะเอาจากที่ไหน"
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 16
                color: presentation.ink
                opacity: 0.75
                wrapMode: Text.WordWrap
                text: "All three package managers work, and .deb files install directly."
            }
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: presentation.paper }
        Column {
            anchors.centerIn: parent
            spacing: 18
            width: parent.width * 0.8

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 30
                font.bold: true
                color: presentation.blue
                wrapMode: Text.WordWrap
                text: "ภาษาไทยพร้อมใช้ทันที"
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 20
                color: presentation.ink
                wrapMode: Text.WordWrap
                text: "ฟอนต์ SIPA ครบชุด แป้นพิมพ์ไทย–อังกฤษ\nสลับภาษาด้วย Alt + Shift ซ้าย"
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 16
                color: presentation.ink
                opacity: 0.75
                wrapMode: Text.WordWrap
                text: "Thai fonts, keyboard and translations are already set up."
            }
        }
    }
}
