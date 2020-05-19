/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                  2.11
import QtQuick.Controls         2.4
import QtQuick.Dialogs          1.3
import QtQuick.Layouts          1.11

import QtLocation               5.3
import QtPositioning            5.3
import QtQuick.Window           2.2
import QtQml.Models             2.1

import QGroundControl               1.0
import QGroundControl.Airspace      1.0
import QGroundControl.Controllers   1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FlightDisplay 1.0
import QGroundControl.FlightMap     1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Vehicle       1.0

/// Flight Display View
Item {

    PlanMasterController {
        id: _planController
        Component.onCompleted: {
            start(true /* flyView */)
            mainWindow.planMasterControllerView = _planController
        }
    }

    property alias  guidedController:              guidedActionsController
    property bool   activeVehicleJoystickEnabled:  activeVehicle ? activeVehicle.joystickEnabled : false
    property bool   mainIsMap:                     QGroundControl.videoManager.hasVideo ? false : true //QGroundControl.loadBoolGlobalSetting(_mainIsMapKey,  true) : true
    property bool   isBackgroundDark:              mainIsMap ? (mainWindow.flightDisplayMap ? mainWindow.flightDisplayMap.isSatelliteMap : true) : true


    property var    _missionController:             _planController.missionController
    property var    _geoFenceController:            _planController.geoFenceController
    property var    _rallyPointController:          _planController.rallyPointController
    property bool   _isPipVisible:                  false //QGroundControl.videoManager.hasVideo ? QGroundControl.loadBoolGlobalSetting(_PIPVisibleKey, true) : false
    property bool   _useChecklist:                  QGroundControl.settingsManager.appSettings.useChecklist.rawValue && QGroundControl.corePlugin.options.preFlightChecklistUrl.toString().length
    property bool   _enforceChecklist:              _useChecklist && QGroundControl.settingsManager.appSettings.enforceChecklist.rawValue
    property bool   _checklistComplete:             activeVehicle && (activeVehicle.checkListState === Vehicle.CheckListPassed)
    property real   _margins:                       ScreenTools.defaultFontPixelWidth / 2
    property real   _pipSize:                       mainWindow.width * 0.2
    property alias  _guidedController:              guidedActionsController
    property alias  _altitudeSlider:                altitudeSlider
    property real   _toolsMargin:                   ScreenTools.defaultFontPixelWidth * 0.75
    property var    _videoReceiver:                 QGroundControl.videoManager.videoReceiver
    property bool   _recordingVideo:                _videoReceiver && _videoReceiver.recording
    property bool   _videoRunning:                  _videoReceiver && _videoReceiver.videoRunning
    property bool   _audioRunning:                  _videoReceiver && _videoReceiver.audioRunning
    property bool   _streamingEnabled:              QGroundControl.settingsManager.videoSettings.streamConfigured
    property bool   _audioEnabled:                  QGroundControl.settingsManager.videoSettings.audioEnabled

    readonly property var       _dynamicCameras:        activeVehicle ? activeVehicle.dynamicCameras : null
    readonly property bool      _isCamera:              _dynamicCameras ? _dynamicCameras.cameras.count > 0 : false
    readonly property real      _defaultRoll:           0
    readonly property real      _defaultPitch:          0
    readonly property real      _defaultHeading:        0
    readonly property real      _defaultAltitudeAMSL:   0
    readonly property real      _defaultGroundSpeed:    0
    readonly property real      _defaultAirSpeed:       0
    readonly property string    _mapName:               "FlightDisplayView"
    readonly property string    _showMapBackgroundKey:  "/showMapBackground"
    readonly property string    _mainIsMapKey:          "MainFlyWindowIsMap"
    readonly property string    _PIPVisibleKey:         "IsPIPVisible"

    Timer {
        id:             checklistPopupTimer
        interval:       1000
        repeat:         false
        onTriggered: {
            if (visible && !_checklistComplete) {
                checklistDropPanel.open()
            }
            else {
                checklistDropPanel.close()
            }
        }
    }

    function setStates() {
        QGroundControl.saveBoolGlobalSetting(_mainIsMapKey, mainIsMap)
        if(mainIsMap) {
            //-- Adjust Margins
            _flightMapContainer.state   = "fullMode"
            _flightVideo.state          = "pipMode"
        } else {
            //-- Adjust Margins
            _flightMapContainer.state   = "pipMode"
            _flightVideo.state          = "fullMode"
        }
    }

    function setPipVisibility(state) {
        _isPipVisible = state;
        QGroundControl.saveBoolGlobalSetting(_PIPVisibleKey, state)
    }

    function isInstrumentRight() {
        if(QGroundControl.corePlugin.options.instrumentWidget) {
            if(QGroundControl.corePlugin.options.instrumentWidget.source.toString().length) {
                switch(QGroundControl.corePlugin.options.instrumentWidget.widgetPosition) {
                case CustomInstrumentWidget.POS_TOP_LEFT:
                case CustomInstrumentWidget.POS_BOTTOM_LEFT:
                case CustomInstrumentWidget.POS_CENTER_LEFT:
                    return false;
                }
            }
        }
        return true;
    }

    function showPreflightChecklistIfNeeded () {
        if (activeVehicle && !_checklistComplete && _enforceChecklist) {
            checklistPopupTimer.restart()
        }
    }


    Connections {
        target:                     _missionController
        onResumeMissionUploadFail:  guidedActionsController.confirmAction(guidedActionsController.actionResumeMissionUploadFail)
    }

    Connections {
        target:                 mainWindow
        onArmVehicle:           guidedController.confirmAction(guidedController.actionArm)
        onDisarmVehicle: {
            if (guidedController.showEmergenyStop) {
                guidedController.confirmAction(guidedController.actionEmergencyStop)
            } else {
                guidedController.confirmAction(guidedController.actionDisarm)
            }
        }
        onVtolTransitionToFwdFlight:    guidedController.confirmAction(guidedController.actionVtolTransitionToFwdFlight)
        onVtolTransitionToMRFlight:     guidedController.confirmAction(guidedController.actionVtolTransitionToMRFlight)
        onFlightDisplayMapChanged:      setStates()
    }

    Component.onCompleted: {
        if(QGroundControl.corePlugin.options.flyViewOverlay.toString().length) {
            flyViewOverlay.source = QGroundControl.corePlugin.options.flyViewOverlay
        }
        if(QGroundControl.corePlugin.options.preFlightChecklistUrl.toString().length) {
            checkList.source = QGroundControl.corePlugin.options.preFlightChecklistUrl
        }
    }

    // The following code is used to track vehicle states for showing the mission complete dialog
    property bool vehicleArmed:                     activeVehicle ? activeVehicle.armed : true // true here prevents pop up from showing during shutdown
    property bool vehicleWasArmed:                  false
    property bool vehicleInMissionFlightMode:       activeVehicle ? (activeVehicle.flightMode === activeVehicle.missionFlightMode) : false
    property bool vehicleWasInMissionFlightMode:    false
    property bool showMissionCompleteDialog:        vehicleWasArmed && vehicleWasInMissionFlightMode &&
                                                        (_missionController.containsItems || _geoFenceController.containsItems || _rallyPointController.containsItems ||
                                                        (activeVehicle ? activeVehicle.cameraTriggerPoints.count !== 0 : false))


    onVehicleArmedChanged: {
        if (vehicleArmed) {
            vehicleWasArmed = true
            vehicleWasInMissionFlightMode = vehicleInMissionFlightMode
        } else {
            if (showMissionCompleteDialog) {
                mainWindow.showComponentDialog(missionCompleteDialogComponent, qsTr("Flight Plan complete"), mainWindow.showDialogDefaultWidth, StandardButton.Close)
            }
            vehicleWasArmed = false
            vehicleWasInMissionFlightMode = false
        }
    }

    onVehicleInMissionFlightModeChanged: {
        if (vehicleInMissionFlightMode && vehicleArmed) {
            vehicleWasInMissionFlightMode = true
        }
    }


    Component {
        id: missionCompleteDialogComponent

        QGCViewDialog {
            property var activeVehicleCopy: activeVehicle
            onActiveVehicleCopyChanged:
                if (!activeVehicleCopy) {
                    hideDialog()
                }

            QGCFlickable {
                anchors.fill:   parent
                contentHeight:  column.height

                ColumnLayout {
                    id:                 column
                    anchors.margins:    _margins
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    spacing:            ScreenTools.defaultFontPixelHeight

                    QGCLabel {
                        Layout.fillWidth:       true
                        text:                   qsTr("%1 Images Taken").arg(activeVehicle.cameraTriggerPoints.count)
                        horizontalAlignment:    Text.AlignHCenter
                        visible:                activeVehicle.cameraTriggerPoints.count !== 0
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Remove plan from vehicle")
                        visible:            !activeVehicle.connectionLost// && !activeVehicle.apmFirmware  // ArduPilot has a bug somewhere with mission clear
                        onClicked: {
                            _planController.removeAllFromVehicle()
                            hideDialog()
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        Layout.alignment:   Qt.AlignHCenter
                        text:               qsTr("Leave plan on vehicle")
                        onClicked:          hideDialog()
                    }

                    Rectangle {
                        Layout.fillWidth:   true
                        color:              qgcPal.text
                        height:             1
                    }

                    ColumnLayout {
                        Layout.fillWidth:   true
                        spacing:            ScreenTools.defaultFontPixelHeight
                        visible:            !activeVehicle.connectionLost && _guidedController.showResumeMission

                        QGCButton {
                            Layout.fillWidth:   true
                            Layout.alignment:   Qt.AlignHCenter
                            text:               qsTr("Resume Mission From Waypoint %1").arg(_guidedController._resumeMissionIndex)

                            onClicked: {
                                guidedController.executeAction(_guidedController.actionResumeMission, null, null)
                                hideDialog()
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               qsTr("Resume Mission will rebuild the current mission from the last flown waypoint and upload it to the vehicle for the next flight.")
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth:   true
                        wrapMode:           Text.WordWrap
                        color:              qgcPal.warningText
                        text:               qsTr("If you are changing batteries for Resume Mission do not disconnect from the vehicle.")
                        visible:            _guidedController.showResumeMission
                    }
                }
            }
        }
    }

    Window {
        id:             videoWindow
        width:          !mainIsMap ? _mapAndVideo.width  : _pipSize
        height:         !mainIsMap ? _mapAndVideo.height : _pipSize * (9/16)
        visible:        false

        Item {
            id:             videoItem
            anchors.fill:   parent
        }

        onClosing: {
            _flightVideo.state = "unpopup"
            videoWindow.visible = false
        }
    }

    /* This timer will startVideo again after the popup window appears and is loaded.
     * Such approach was the only one to avoid a crash for windows users
     */
    Timer {
      id: videoPopUpTimer
      interval: 2000;
      running: false;
      repeat: false
      onTriggered: {
          // If state is popup, the next one will be popup-finished
          if (_flightVideo.state ==  "popup") {
            _flightVideo.state = "popup-finished"
          }
          QGroundControl.videoManager.startVideo()
      }
    }

    QGCMapPalette { id: mapPal; lightColors: mainIsMap ? mainWindow.flightDisplayMap.isSatelliteMap : true }

    Item {
        id:             _mapAndVideo
        anchors.fill:   parent

        //-- Map View
        Item {
            id: _flightMapContainer
            z:  mainIsMap ? _mapAndVideo.z + 1 : _mapAndVideo.z + 2
            anchors.left:   _mapAndVideo.left
            anchors.bottom: _mapAndVideo.bottom
            visible:        mainIsMap || _isPipVisible && !QGroundControl.videoManager.fullScreen
            width:          mainIsMap ? _mapAndVideo.width  : _pipSize
            height:         mainIsMap ? _mapAndVideo.height : _pipSize * (9/16)
            states: [
                State {
                    name:   "pipMode"
                    PropertyChanges {
                        target:             _flightMapContainer
                        anchors.margins:    ScreenTools.defaultFontPixelHeight
                    }
                },
                State {
                    name:   "fullMode"
                    PropertyChanges {
                        target:             _flightMapContainer
                        anchors.margins:    0
                    }
                }
            ]
            FlightDisplayViewMap {
                id:                         _fMap
                anchors.fill:               parent
                guidedActionsController:    _guidedController
                missionController:          _planController
                flightWidgets:              flightDisplayViewWidgets
                rightPanelWidth:            ScreenTools.defaultFontPixelHeight * 9
                multiVehicleView:           !singleVehicleView.checked
                scaleState:                 (mainIsMap && flyViewOverlay.item) ? (flyViewOverlay.item.scaleState ? flyViewOverlay.item.scaleState : "bottomMode") : "bottomMode"
                Component.onCompleted: {
                    mainWindow.flightDisplayMap = _fMap
                    _fMap.adjustMapSize()
                }
            }
        }

        //-- Video View
        Item {
            id:             _flightVideo
            z:              mainIsMap ? _mapAndVideo.z + 2 : _mapAndVideo.z + 1
            width:          !mainIsMap ? _mapAndVideo.width  : _pipSize
            height:         !mainIsMap ? _mapAndVideo.height : _pipSize * (9/16)
            anchors.left:   _mapAndVideo.left
            anchors.bottom: _mapAndVideo.bottom
            visible:        QGroundControl.videoManager.hasVideo && (!mainIsMap || _isPipVisible)

            onParentChanged: {
                /* If video comes back from popup
                 * correct anchors.
                 * Such thing is not possible with ParentChange.
                 */
                if(parent == _mapAndVideo) {
                    // Do anchors again after popup
                    anchors.left =       _mapAndVideo.left
                    anchors.bottom =     _mapAndVideo.bottom
                    anchors.margins =    _toolsMargin
                }
            }

            states: [
                State {
                    name:   "pipMode"
                    PropertyChanges {
                        target:             _flightVideo
                        anchors.margins:    ScreenTools.defaultFontPixelHeight
                    }
                    PropertyChanges {
                        target:             _flightVideoPipControl
                        inPopup:            false
                    }
                },
                State {
                    name:   "fullMode"
                    PropertyChanges {
                        target:             _flightVideo
                        anchors.margins:    0
                    }
                    PropertyChanges {
                        target:             _flightVideoPipControl
                        inPopup:            false
                    }
                },
                State {
                    name: "popup"
                    StateChangeScript {
                        script: {
                            // Stop video, restart it again with Timer
                            // Avoiding crashes if ParentChange is not yet done
                            QGroundControl.videoManager.stopVideo()
                            videoPopUpTimer.running = true
                        }
                    }
                    PropertyChanges {
                        target:             _flightVideoPipControl
                        inPopup:            true
                    }
                },
                State {
                    name: "popup-finished"
                    ParentChange {
                        target:             _flightVideo
                        parent:             videoItem
                        x:                  0
                        y:                  0
                        width:              videoItem.width
                        height:             videoItem.height
                    }
                },
                State {
                    name: "unpopup"
                    StateChangeScript {
                        script: {
                            QGroundControl.videoManager.stopVideo()
                            videoPopUpTimer.running = true
                        }
                    }
                    ParentChange {
                        target:             _flightVideo
                        parent:             _mapAndVideo
                    }
                    PropertyChanges {
                        target:             _flightVideoPipControl
                        inPopup:             false
                    }
                }
            ]
            //-- Video Streaming
            FlightDisplayViewVideo {
                id:             videoStreaming
                anchors.fill:   parent
                visible:        QGroundControl.videoManager.isGStreamer
            }
            //-- UVC Video (USB Camera or Video Device)
            Loader {
                id:             cameraLoader
                anchors.fill:   parent
                visible:        !QGroundControl.videoManager.isGStreamer
                source:         visible ? (QGroundControl.videoManager.uvcEnabled ? "qrc:/qml/FlightDisplayViewUVC.qml" : "qrc:/qml/FlightDisplayViewDummy.qml") : ""
            }
        }

        QGCPipable {
            id:                 _flightVideoPipControl
            z:                  _flightVideo.z + 3
            width:              _pipSize
            height:             _pipSize * (9/16)
            anchors.left:       _mapAndVideo.left
            anchors.bottom:     _mapAndVideo.bottom
            anchors.margins:    ScreenTools.defaultFontPixelHeight
            visible:            QGroundControl.videoManager.hasVideo && !QGroundControl.videoManager.fullScreen && _flightVideo.state != "popup"
            isHidden:           !_isPipVisible
            isDark:             isBackgroundDark
            enablePopup:        mainIsMap
            onActivated: {
                mainIsMap = !mainIsMap
                setStates()
                _fMap.adjustMapSize()
            }
            onHideIt: {
                setPipVisibility(!state)
            }
            onPopup: {
                videoWindow.visible = true
                _flightVideo.state = "popup"
            }
            onNewWidth: {
                _pipSize = newWidth
            }
        }

        Row {
            id:                     singleMultiSelector
            anchors.topMargin:      ScreenTools.toolbarHeight + _toolsMargin
            anchors.rightMargin:    _toolsMargin
            anchors.right:          parent.right
            spacing:                ScreenTools.defaultFontPixelWidth
            z:                      _mapAndVideo.z + 4
            visible:                QGroundControl.multiVehicleManager.vehicles.count > 1 && QGroundControl.corePlugin.options.enableMultiVehicleList

            QGCRadioButton {
                id:             singleVehicleView
                text:           qsTr("Single")
                checked:        true
                textColor:      mapPal.text
            }

            QGCRadioButton {
                text:           qsTr("Multi-Vehicle")
                textColor:      mapPal.text
            }
        }

        FlightDisplayViewWidgets {
            id:                 flightDisplayViewWidgets
            z:                  _mapAndVideo.z + 4
            height:             availableHeight - (singleMultiSelector.visible ? singleMultiSelector.height + _toolsMargin : 0) - _toolsMargin
            anchors.left:       parent.left
            anchors.right:      altitudeSlider.visible ? altitudeSlider.left : parent.right
            anchors.bottom:     parent.bottom
            anchors.top:        singleMultiSelector.visible? singleMultiSelector.bottom : undefined
            useLightColors:     isBackgroundDark
            missionController:  _missionController
            visible:            singleVehicleView.checked && !QGroundControl.videoManager.fullScreen
        }

        //-------------------------------------------------------------------------
        //-- Loader helper for plugins to overlay elements over the fly view
        Loader {
            id:                 flyViewOverlay
            z:                  flightDisplayViewWidgets.z + 1
            visible:            !QGroundControl.videoManager.fullScreen
            height:             mainWindow.height - mainWindow.header.height
            anchors.left:       parent.left
            anchors.right:      altitudeSlider.visible ? altitudeSlider.left : parent.right
            anchors.bottom:     parent.bottom
        }

        MultiVehicleList {
            anchors.margins:            _toolsMargin
            anchors.top:                singleMultiSelector.bottom
            anchors.right:              parent.right
            anchors.bottom:             parent.bottom
            width:                      ScreenTools.defaultFontPixelWidth * 30
            visible:                    !singleVehicleView.checked && !QGroundControl.videoManager.fullScreen && QGroundControl.corePlugin.options.enableMultiVehicleList
            z:                          _mapAndVideo.z + 4
            guidedActionsController:    _guidedController
        }

        //Nightcrawler/Patrios video recording Button
        // Button to start/stop video recording
        /*
        Item {
            anchors.right:              parent.right
            anchors.bottom:             patriosBox.top
            anchors.bottomMargin:       ScreenTools.toolbarHeight + _margins
            anchors.rightMargin:        ScreenTools.defaultFontPixelHeight * 2
            anchors.margins:            ScreenTools.defaultFontPixelHeight / 2
            height:                     ScreenTools.defaultFontPixelHeight * 2
            width:                      height
            z:                          _mapAndVideo.z + 5
            visible:            true //QGroundControl.videoManager.isGStreamer
            Rectangle {
                id:                 recordBtnBackground
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                width:              height
                radius:             _recordingVideo ? 0 : height
                color:              (_videoRunning && _streamingEnabled) ? "red" : "gray"
                SequentialAnimation on opacity {
                    running:        _recordingVideo
                    loops:          Animation.Infinite
                    PropertyAnimation { to: 0.5; duration: 500 }
                    PropertyAnimation { to: 1.0; duration: 500 }
                }
            }
            QGCColoredImage {
                anchors.top:                parent.top
                anchors.bottom:             parent.bottom
                anchors.horizontalCenter:   parent.horizontalCenter
                width:                      height * 0.625
                sourceSize.width:           width
                source:                     "/qmlimages/CameraIcon.svg"
                visible:                    recordBtnBackground.visible
                fillMode:                   Image.PreserveAspectFit
                color:                      "white"
            }
            MouseArea {
                anchors.fill:   parent
                enabled:        _videoRunning && _streamingEnabled
                onClicked: {
                    if (_recordingVideo) {
                        _videoReceiver.stopRecording()
                        // reset blinking animation
                        recordBtnBackground.opacity = 1
                    } else {
                        _videoReceiver.startRecording(videoFileName.text)
                    }
                }
            }
        }
        */
        //Nightcrawler/Patrios specific feedback panel



        Rectangle {
            id:                 patriosBox
            width:  patriosCol.width   + ScreenTools.defaultFontPixelWidth  * 3
            height: patriosCol.height  + ScreenTools.defaultFontPixelHeight * 2
            radius: ScreenTools.defaultFontPixelHeight * 0.5
            color:  Qt.rgba(0,0,0,0.5)
            border.color:   qgcPal.text
            anchors.right:              parent.right
            anchors.bottom:             parent.bottom
            anchors.bottomMargin:       ScreenTools.toolbarHeight + _margins
            anchors.rightMargin:       ScreenTools.defaultFontPixelHeight * 2
            visible:        activeVehicle && !QGroundControl.videoManager.fullScreen
            z:                          _mapAndVideo.z + 5

            Column {
                id:                 patriosCol
                spacing:            ScreenTools.defaultFontPixelHeight * 0.5
                width:              Math.max(patriosGrid.width, patriosLabel.width)
                anchors.margins:    ScreenTools.defaultFontPixelHeight
                anchors.centerIn:   parent

                QGCLabel {
                    id:             patriosLabel
                    text:           qsTr("Vehicle Status")
                    color:          "white"
                    font.family:    ScreenTools.demiboldFontFamily
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                GridLayout {
                    id:                 patriosGrid
                    anchors.margins:    ScreenTools.defaultFontPixelHeight
                    columnSpacing:      ScreenTools.defaultFontPixelWidth
                    columns:            2
                    anchors.horizontalCenter: parent.horizontalCenter

                    QGCLabel {
                        text: qsTr("Audio Enable:")
                        color: "white"
                        visible:  QGroundControl.videoManager.isGStreamer && _videoRunning && _audioEnabled
                    }
                    Item {
                       // anchors.right:              parent.right
                       // anchors.bottom:             patriosBox.top
                      //  anchors.bottomMargin:       ScreenTools.toolbarHeight + _margins
                      //  anchors.rightMargin:        ScreenTools.defaultFontPixelHeight * 2
                      //  anchors.margins:            ScreenTools.defaultFontPixelHeight / 2
                        height:                     ScreenTools.defaultFontPixelHeight * 2
                        width:                      height
                        z:                          _mapAndVideo.z + 5
                        visible:                    QGroundControl.videoManager.isGStreamer && _videoRunning && _audioEnabled
                        Rectangle {
                            id:                 audioBtnBackground
                            anchors.top:        parent.top
                            anchors.bottom:     parent.bottom
                            width:              height
                            radius:             height //_recordingVideo ? 0 : height
                            color:              (_audioRunning && _streamingEnabled) ? "blue" : "gray"//(_videoRunning && _streamingEnabled) ? "red" : "gray"
                            SequentialAnimation on opacity {
                                running:        _audioRunning
                                loops:          Animation.Infinite
                                PropertyAnimation { to: 0.5; duration: 500 }
                                PropertyAnimation { to: 1.0; duration: 500 }
                            }
                        }
                        QGCColoredImage {
                            anchors.top:                parent.top
                            anchors.bottom:             parent.bottom
                            anchors.horizontalCenter:   parent.horizontalCenter
                            width:                      height * 0.625
                            sourceSize.width:           width
                            source:                     "/qmlimages/SpeakerIcon.svg"
                            visible:                    audioBtnBackground.visible
                            fillMode:                   Image.PreserveAspectFit
                            color:                      "white"
                        }
                        MouseArea {
                            anchors.fill:   parent
                            enabled:        _videoRunning && _streamingEnabled
                            onClicked: {
                                if (_audioRunning) {
                                    _videoReceiver.stopAudio()
                                    // reset blinking animation
                                    audioBtnBackground.opacity = 1
                                } else {
                                    _videoReceiver.startAudio()
                                }
                            }
                        }
                    }
                    QGCLabel {
                        text: qsTr("Video Recording:")
                        color: "white"
                        visible:  QGroundControl.videoManager.isGStreamer && _videoRunning
                    }
                    Item {
                       // anchors.right:              parent.right
                       // anchors.bottom:             patriosBox.top
                      //  anchors.bottomMargin:       ScreenTools.toolbarHeight + _margins
                      //  anchors.rightMargin:        ScreenTools.defaultFontPixelHeight * 2
                      //  anchors.margins:            ScreenTools.defaultFontPixelHeight / 2
                        height:                     ScreenTools.defaultFontPixelHeight * 2
                        width:                      height
                        z:                          _mapAndVideo.z + 5
                        visible:                    QGroundControl.videoManager.isGStreamer && _videoRunning
                        Rectangle {
                            id:                 recordBtnBackground
                            anchors.top:        parent.top
                            anchors.bottom:     parent.bottom
                            width:              height
                            radius:             height //_recordingVideo ? 0 : height
                            color:              (_videoRunning && _streamingEnabled && _recordingVideo) ? "red" : "gray"//(_videoRunning && _streamingEnabled) ? "red" : "gray"
                            SequentialAnimation on opacity {
                                running:        _recordingVideo
                                loops:          Animation.Infinite
                                PropertyAnimation { to: 0.5; duration: 500 }
                                PropertyAnimation { to: 1.0; duration: 500 }
                            }
                        }
                        QGCColoredImage {
                            anchors.top:                parent.top
                            anchors.bottom:             parent.bottom
                            anchors.horizontalCenter:   parent.horizontalCenter
                            width:                      height * 0.625
                            sourceSize.width:           width
                            source:                     "/qmlimages/CameraIcon.svg"
                            visible:                    recordBtnBackground.visible
                            fillMode:                   Image.PreserveAspectFit
                            color:                      "white"
                        }
                        MouseArea {
                            anchors.fill:   parent
                            enabled:        _videoRunning && _streamingEnabled
                            onClicked: {
                                if (_recordingVideo) {
                                    _videoReceiver.stopRecording()
                                    // reset blinking animation
                                    recordBtnBackground.opacity = 1
                                } else {
                                    _videoReceiver.startRecording()
                                }
                            }
                        }
                    }                   
                    QGCLabel {
                        text: qsTr("Active Camera:")
                        color: "white"                    
                    }
                    QGCLabel {
                        text: getCamName()
                        color: "white"
                        function getCamName() {
                            if (activeVehicle)
                            {
                                if (!_videoRunning)
                                    return qsTr("No Stream")
                                if(activeVehicle.currentCamera === 0)
                                    return qsTr("Front")
                                else if (activeVehicle.currentCamera === 1)
                                    return qsTr("Thermal")
                                else
                                    return qsTr("Rear")
                                }
                            return qsTr("Loading..")
                            }


                    }
                    QGCLabel {
                        text: qsTr("Lights:")
                        color: "white"
                    }
                    QGCLabel {
                        text: getLightModeName()
                        color: "white"
                        function getLightModeName() {
                            if (activeVehicle)
                            {
                            if(activeVehicle.currentLight === 0)
                                return qsTr("Off")
                            else if (activeVehicle.currentLight === 1)
                                return qsTr("Overt On")
                            else
                                return qsTr("IR On")
                            }
                            return  qsTr("Loading..")
                        }

                    }

                    QGCLabel {
                        text: qsTr("Steering Mode:")
                        color: "white"
                    }
                    QGCLabel {
                        text: (activeVehicle) ? (activeVehicle.fourWheelSteering ? "4W" : "2W") : "Loading..";
                        color: "white"
                    }
                    QGCLabel {
                        text: qsTr("Speed Mode:")
                        color: "white"
                    }
                    QGCLabel {
                        text: (activeVehicle) ? (activeVehicle.slowSpeedMode ? "Slow" : "Fast") : "Loading..";
                        color: "white"
                    }
                    QGCLabel {
                        text: qsTr("Weapons:")
                        color: "white"
                    }
                    QGCLabel {
                        text: getArmStatus()
                        color: (activeVehicle) ? ((activeVehicle.weaponsPreArmed) ? "red" : "white") : "Loading..";
                         function getArmStatus() {
                             if (activeVehicle)
                            {
                             if (activeVehicle.weaponsArmed && activeVehicle.weaponsPreArmed)
                                 return qsTr("FIRE STEP 1 of 2")
                             if (activeVehicle.weaponsPreArmed)
                                 return qsTr("ARMED")
                             else
                                 return qsTr("Disarmed")
                            }
                            return  qsTr("Loading..")
                        }
                    }
                }
            }
        }

        Rectangle {
            id:             nc_weapon_arm
            anchors.bottom:             parent.bottom
            anchors.bottomMargin:       ScreenTools.defaultFontPixelHeight * 2
            anchors.horizontalCenter:   parent.horizontalCenter
            color:          Qt.rgba(0,0,0,0.75)
            visible:        (activeVehicle) ? activeVehicle.weaponsPreArmed  : false
            z:                          _mapAndVideo.z + 5
            QGCLabel {                
                text:               "WEAPONS ARMED!"
                font.family:        ScreenTools.demiboldFontFamily
                color:              "red"
                font.pointSize:     ScreenTools.largeFontPointSize
                anchors.centerIn:   parent

            }
        }
        //-- Virtual Joystick
        Loader {
            id:                         virtualJoystickMultiTouch
            z:                          _mapAndVideo.z + 5
            width:                      parent.width  - (_flightVideoPipControl.width / 2)
            height:                     Math.min(mainWindow.height * 0.25, ScreenTools.defaultFontPixelWidth * 16)
            visible:                    (_virtualJoystick ? _virtualJoystick.value : false) && !QGroundControl.videoManager.fullScreen && !(activeVehicle ? activeVehicle.highLatencyLink : false)
            anchors.bottom:             _flightVideoPipControl.top
            anchors.bottomMargin:       ScreenTools.defaultFontPixelHeight * 2
            anchors.horizontalCenter:   flightDisplayViewWidgets.horizontalCenter
            source:                     "qrc:/qml/VirtualJoystick.qml"
            active:                     (_virtualJoystick ? _virtualJoystick.value : false) && !(activeVehicle ? activeVehicle.highLatencyLink : false)

            property bool useLightColors: isBackgroundDark
            // The default behaviour is not centralized throttle
            property bool centralizeThrottle: _virtualJoystickCentralized ? _virtualJoystickCentralized.value : false

            property Fact _virtualJoystick: QGroundControl.settingsManager.appSettings.virtualJoystick
            property Fact _virtualJoystickCentralized: QGroundControl.settingsManager.appSettings.virtualJoystickCentralized
        }



        ToolStrip {
            //visible:            (activeVehicle ? activeVehicle.guidedModeSupported : true) && !QGroundControl.videoManager.fullScreen
            visible: false
            id:                 toolStrip

            anchors.leftMargin: isInstrumentRight() ? _toolsMargin : undefined
            anchors.left:       isInstrumentRight() ? _mapAndVideo.left : undefined
            anchors.rightMargin:isInstrumentRight() ? undefined : ScreenTools.defaultFontPixelWidth
            anchors.right:      isInstrumentRight() ? undefined : _mapAndVideo.right
            anchors.topMargin:  _toolsMargin
            anchors.top:        parent.top
            z:                  _mapAndVideo.z + 4
            maxHeight:          parent.height - toolStrip.y + (_flightVideo.visible ? (_flightVideo.y - parent.height) : 0)
            title:              qsTr("Fly")

            property bool _anyActionAvailable: _guidedController.showStartMission || _guidedController.showResumeMission || _guidedController.showChangeAlt || _guidedController.showLandAbort
            property var _actionModel: [
                {
                    title:      _guidedController.startMissionTitle,
                    text:       _guidedController.startMissionMessage,
                    action:     _guidedController.actionStartMission,
                    visible:    _guidedController.showStartMission
                },
                {
                    title:      _guidedController.continueMissionTitle,
                    text:       _guidedController.continueMissionMessage,
                    action:     _guidedController.actionContinueMission,
                    visible:    _guidedController.showContinueMission
                },
                {
                    title:      _guidedController.changeAltTitle,
                    text:       _guidedController.changeAltMessage,
                    action:     _guidedController.actionChangeAlt,
                    visible:    _guidedController.showChangeAlt
                },
                {
                    title:      _guidedController.landAbortTitle,
                    text:       _guidedController.landAbortMessage,
                    action:     _guidedController.actionLandAbort,
                    visible:    _guidedController.showLandAbort
                }
            ]

            model: [
                {
                    name:               "Checklist",
                    iconSource:         "/qmlimages/check.svg",
                    buttonVisible:      _useChecklist,
                    buttonEnabled:      _useChecklist && activeVehicle && !activeVehicle.armed,
                },
                {
                    name:               _guidedController.takeoffTitle,
                    iconSource:         "/res/takeoff.svg",
                    buttonVisible:      _guidedController.showTakeoff || !_guidedController.showLand,
                    buttonEnabled:      _guidedController.showTakeoff,
                    action:             _guidedController.actionTakeoff
                },
                {
                    name:               _guidedController.landTitle,
                    iconSource:         "/res/land.svg",
                    buttonVisible:      _guidedController.showLand && !_guidedController.showTakeoff,
                    buttonEnabled:      _guidedController.showLand,
                    action:             _guidedController.actionLand
                },
                {
                    name:               _guidedController.rtlTitle,
                    iconSource:         "/res/rtl.svg",
                    buttonVisible:      true,
                    buttonEnabled:      _guidedController.showRTL,
                    action:             _guidedController.actionRTL
                },
                {
                    name:               _guidedController.pauseTitle,
                    iconSource:         "/res/pause-mission.svg",
                    buttonVisible:      _guidedController.showPause,
                    buttonEnabled:      _guidedController.showPause,
                    action:             _guidedController.actionPause
                },
                {
                    name:               qsTr("Action"),
                    iconSource:         "/res/action.svg",
                    buttonVisible:      _anyActionAvailable,
                    action:             -1
                }
            ]

            onClicked: {
                if(index === 0) {
                    checklistDropPanel.open()
                } else {
                    guidedActionsController.closeAll()
                    var action = model[index].action
                    if (action === -1) {
                        guidedActionList.model   = _actionModel
                        guidedActionList.visible = true
                    } else {
                        _guidedController.confirmAction(action)
                    }
                }

            }
        }

        GuidedActionsController {
            id:                 guidedActionsController
            missionController:  _missionController
            confirmDialog:      guidedActionConfirm
            actionList:         guidedActionList
            altitudeSlider:     _altitudeSlider
            z:                  _flightVideoPipControl.z + 1

            onShowStartMissionChanged: {
                if (showStartMission) {
                    confirmAction(actionStartMission)
                }
            }

            onShowContinueMissionChanged: {
                if (showContinueMission) {
                    confirmAction(actionContinueMission)
                }
            }

            onShowLandAbortChanged: {
                if (showLandAbort) {
                    confirmAction(actionLandAbort)
                }
            }

            /// Close all dialogs
            function closeAll() {
                guidedActionConfirm.visible = false
                guidedActionList.visible    = false
                altitudeSlider.visible      = false
            }
        }

        GuidedActionConfirm {
            id:                         guidedActionConfirm
            anchors.margins:            _margins
            anchors.bottom:             parent.bottom
            anchors.horizontalCenter:   parent.horizontalCenter
            guidedController:           _guidedController
            altitudeSlider:             _altitudeSlider
        }

        GuidedActionList {
            id:                         guidedActionList
            anchors.margins:            _margins
            anchors.bottom:             parent.bottom
            anchors.horizontalCenter:   parent.horizontalCenter
            guidedController:           _guidedController
        }

        //-- Altitude slider
        GuidedAltitudeSlider {
            id:                 altitudeSlider
            anchors.margins:    _margins
            anchors.right:      parent.right
            anchors.topMargin:  ScreenTools.toolbarHeight + _margins
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            z:                  _guidedController.z
            radius:             ScreenTools.defaultFontPixelWidth / 2
            width:              ScreenTools.defaultFontPixelWidth * 10
            color:              qgcPal.window
            visible:            false
        }
    }

    //-- Airspace Indicator
    Rectangle {
        id:             airspaceIndicator
        width:          airspaceRow.width + (ScreenTools.defaultFontPixelWidth * 3)
        height:         airspaceRow.height * 1.25
        color:          qgcPal.globalTheme === QGCPalette.Light ? Qt.rgba(1,1,1,0.95) : Qt.rgba(0,0,0,0.75)
        visible:        QGroundControl.airmapSupported && mainIsMap && flightPermit && flightPermit !== AirspaceFlightPlanProvider.PermitNone
        radius:         3
        border.width:   1
        border.color:   qgcPal.globalTheme === QGCPalette.Light ? Qt.rgba(0,0,0,0.35) : Qt.rgba(1,1,1,0.35)
        anchors.top:    parent.top
        anchors.topMargin: ScreenTools.toolbarHeight + (ScreenTools.defaultFontPixelHeight * 0.25)
        anchors.horizontalCenter: parent.horizontalCenter
        Row {
            id: airspaceRow
            spacing: ScreenTools.defaultFontPixelWidth
            anchors.centerIn: parent
            QGCLabel { text: airspaceIndicator.providerName+":"; anchors.verticalCenter: parent.verticalCenter; }
            QGCLabel {
                text: {
                    if(airspaceIndicator.flightPermit) {
                        if(airspaceIndicator.flightPermit === AirspaceFlightPlanProvider.PermitPending)
                            return qsTr("Approval Pending")
                        if(airspaceIndicator.flightPermit === AirspaceFlightPlanProvider.PermitAccepted || airspaceIndicator.flightPermit === AirspaceFlightPlanProvider.PermitNotRequired)
                            return qsTr("Flight Approved")
                        if(airspaceIndicator.flightPermit === AirspaceFlightPlanProvider.PermitRejected)
                            return qsTr("Flight Rejected")
                    }
                    return ""
                }
                color: {
                    if(airspaceIndicator.flightPermit) {
                        if(airspaceIndicator.flightPermit === AirspaceFlightPlanProvider.PermitPending)
                            return qgcPal.colorOrange
                        if(airspaceIndicator.flightPermit === AirspaceFlightPlanProvider.PermitAccepted || airspaceIndicator.flightPermit === AirspaceFlightPlanProvider.PermitNotRequired)
                            return qgcPal.colorGreen
                    }
                    return qgcPal.colorRed
                }
                anchors.verticalCenter: parent.verticalCenter;
            }
        }
        property var  flightPermit: QGroundControl.airmapSupported ? QGroundControl.airspaceManager.flightPlan.flightPermitStatus : null
        property string  providerName: QGroundControl.airspaceManager.providerName
    }

    //-- Checklist GUI
    Popup {
        id:             checklistDropPanel
        x:              Math.round((mainWindow.width  - width)  * 0.5)
        y:              Math.round((mainWindow.height - height) * 0.5)
        height:         checkList.height
        width:          checkList.width
        modal:          true
        focus:          true
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            anchors.fill:  parent
            color:      Qt.rgba(0,0,0,0)
            clip:       true
        }

        Loader {
            id:         checkList
            anchors.centerIn: parent
        }

        property alias checkListItem: checkList.item

        Connections {
            target: checkList.item
            onAllChecksPassedChanged: {
                if (target.allChecksPassed)
                {
                    checklistPopupTimer.restart()
                }
            }
        }
    }

}
