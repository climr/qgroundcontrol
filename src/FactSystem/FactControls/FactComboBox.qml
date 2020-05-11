import QtQuick 2.3
import QtQuick.Controls 1.2
import QtQuick.Controls.Styles 1.4

import QGroundControl.FactSystem 1.0
import QGroundControl.Palette 1.0
import QGroundControl.Controls 1.0
import QGroundControl                       1.0
import QGroundControl.SettingsManager       1.0


QGCComboBox {
    property Fact fact: Fact { }
    property bool indexModel: true  ///< true: model must be specifed, selected index is fact value, false: use enum meta data

    property string _videoSource:               QGroundControl.settingsManager.videoSettings.videoSource.value
    property bool   _isGst:                     QGroundControl.videoManager.isGStreamer
    property bool   _isMulticastUDP264:         _isGst && _videoSource === QGroundControl.settingsManager.videoSettings.multicastUdp264VideoSource
    property bool   _isUDP264:                  _isGst && _videoSource === QGroundControl.settingsManager.videoSettings.udp264VideoSource

    model: fact ? fact.enumStrings : null

    currentIndex: fact ? (indexModel ? fact.value : fact.enumIndex) : 0

    onActivated: {
        if (indexModel) {
            fact.value = index
        } else {
            fact.value = fact.enumValues[index]
        }
     //   console.log(fact.value + " isIDP264:" + _isUDP264 + " isGst:" + _isGst)
    }
}
