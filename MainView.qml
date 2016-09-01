import QtQuick 2.1
import QtQuick.Controls 1.4

GridView {
    id: view

    width: parent.width
    height: parent.height

    property int rows: 9
    property int columns: 9
    property int folderIndex: -1
    property bool launcherEditMode: false
    property bool rootFolder: true //useless atm, indicate launcher of folder view
    property alias launcherModel: view.model

    property Item movingItem //current Item that is moving

    cellWidth: width / rows - 8
    cellHeight: height / columns - 8

    onLauncherEditModeChanged: {
        console.log("========== onLauncherEditModeChanged "+launcherEditMode);
        if (movingItem) {
            movingItem.setColor(launcherEditMode);
        }
    }

    function setEditMode(enabled) {
        launcherEditMode = enabled;
    }

    // trigger when moved
    Timer {
        id: reorderTimer
        interval: 150
        onTriggered: movingItem.doReordering()
    }

    ListModel {
        id: listModel
    }

    Component.onCompleted: {
        for (var i=0; i<81; ++i) {
            var item = {"Text":"i"+i};
            listModel.append(item);
        }
    }

    model: listModel
    delegate: Item {
        id: wrapper
        property int modelIndex: index
        property int newIndex: -1
        property int newFolderIndex: -1
        property real oldY
        property real pressX
        property real pressY
        property bool launcherEditMode: view.launcherEditMode
        property bool dragged
        property bool reordering

        onReorderingChanged: {
            console.log("========== onReorderingChanged "+reordering);
        }

        // Make sure the X and Y coordinates change when the view positions the item
        x: -2000
        y: -2000
        width: cellWidth
        height: cellHeight
        onXChanged: moveTimer.running = true
        onYChanged: moveTimer.running = true

        Timer {
            id: moveTimer
            interval: 1
            onTriggered: {
                if (!reordering) {
                    if (y != oldY) {
                        slideMoveAnim.stop();
                        fadeMoveAnim.start();
                        oldY = y
                    } else if (!fadeMoveAnim.running) {
                        slideMoveAnim.restart();
                    }
                }
            }
        }

        MouseArea {
            id: launcherItem

            function startReordering() {
                if (launcherEditMode && !dragged) {
                    reparent(view);
                    drag.target = launcherItem;
                    z = 1000;
                    reordering = true;
                    dragged = true;
                }
            }

            function setColor(isReordering) {
                if (isReordering) {
                    launcherIcon.border.color = "#f11212";
                    launcherIcon.color = "#1064f5";
                } else {
                    launcherIcon.border.color = "#f37718";
                    launcherIcon.color = "#f52d0e";
                }

            }

            // doReordering when moved, triggered by reorderTimer
            function doReordering() {
                console.log("======== doReordering, newFolderIndex "+newFolderIndex
                            + " newIndex "+ newIndex+ " index "+index);
                if (newFolderIndex >= 0 && newFolderIndex !== index) {
                    console.log("======== doReordering, create folder or move folder position ");
                    view.folderIndex = newFolderIndex;
                } else if (newIndex != -1 && newIndex !== index) {
                    console.log("======== doReordering, move item ");
                    launcherModel.move(index, newIndex, 1);
                }

                newIndex = -1;
            }

            // cancelReordering when released
            function cancelReordering() {
                console.log("======== cancelReordering");
                if (reordering) {
                    reordering = false;
                    reorderTimer.stop();
                    drag.target = null;
                    folderIndex = -1;
                    reparent(view.contentItem);
                    slideMoveAnim.start();
                }
                setEditMode(false)
                if (movingItem == launcherItem) {
                    movingItem = null;
                }
            }

            function reparent(newParent) {
                var newPos = mapToItem(newParent, 0, 0);
                parent = newParent;
                x = newPos.x;
                y = newPos.y;
            }

            function moved() {
                var gridViewPos = view.contentItem.mapFromItem(launcherItem, width/2, height/2);
                var item = view.itemAt(gridViewPos.x, gridViewPos.y);
                console.log("==== moved gridViewPos "+gridViewPos + " item "+item
                            +" itemPos ("+item.x+","+item.y +")");
                var idx = -1;
                var folderIdx = -1;
                if (item) {
                    var offset = gridViewPos.x - item.x;
                    var folderThreshold = view.cellWidth / 4;;

//                    console.log("==== moved offset "+offset);
//                    console.log("==== moved folderThreshold "+folderThreshold);
//                    console.log("==== moved (view.cellWidth - folderThreshold) " +(view.cellWidth - folderThreshold));
//                    console.log("==== moved item.modelIndex "+item.modelIndex +" index "+index);

                    if (offset < folderThreshold) {
                        if (Math.abs(index - item.modelIndex) > 1 || index > item.modelIndex || item.y !== wrapper.y) {
                            idx = index < item.modelIndex ? item.modelIndex - 1 : item.modelIndex;
                        }
                    } else if (offset >= view.cellWidth - folderThreshold) {
                        console.log("==== moved condition 2-1, item.y "+item.y+" wrapper.y "+wrapper.y )
                        if (Math.abs(index - item.modelIndex) > 1 || index < item.modelIndex || item.y !== wrapper.y) {
                            console.log("==== moved condition 2-2");
                            idx = index > item.modelIndex ? item.modelIndex + 1 : item.modelIndex;
                        }
                    } else if (item.modelIndex !== index && rootFolder) {
                        console.log("==== moved condition  folder item");
                        folderIdx = item.modelIndex;
                    }
                } else if (folderIdx < 0 && idx < 0 && gridViewPos.x >= 0 && gridViewPos.x < view.width
                           && gridViewPos.y >= 0) {
                    idx = view.count - 1;
                }

                console.log("===== moved newIndex "+newIndex +"  idx "+idx)
                if (newIndex !== idx) {
                    newIndex = idx;
                    reorderTimer.restart();
                }
                console.log("===== moved newFolderIndex "+newFolderIndex +"  folderIdx "+folderIdx)
                if (newFolderIndex != folderIdx) {
                    newFolderIndex = folderIdx;
                    reorderTimer.restart();
                }
                if (newFolderIndex != view.folderIndex) {
                    view.folderIndex = -1
                }
            }

            x: -2000
            y: -2000
            width: cellWidth
            height: cellHeight
            parent: view.contentItem // make wrapper item as placeholder item
            transformOrigin: Item.Center

            Rectangle {
                id: launcherIcon
                color: "#f52d0e"
                border.color: "#f37718"
                anchors{
                    fill: parent
                    margins: 5
                }

                Label {
                    anchors.centerIn: parent
                    text: model.Text

                }
                anchors.centerIn: parent
            }

            onXChanged: {
                if (wrapper.reordering) {
                    moved();
                }
            }
            onYChanged: {
                if (wrapper.reordering) {
                    moved();
                }
            }

            onClicked: {
                console.log("====== launcherItem onClicked, is dragged "+dragged)
                if (dragged) {
                    return;
                }
            }

            // onPressed -> onPressAndHold -> onPositionChanged -> onReleased
            // onPressed -> onReleased -> onClicked
            onPressAndHold: {
                console.log("============= launcherItem onPressAndHold");
                movingItem = launcherItem;
                newIndex = -1;
                newFolderIndex = -1;
                setEditMode(true);
                startReordering();
            }

            onPressed: {
                console.log("============= launcherItem onPressed");
                // The currentIndex will not be destroyed when we scroll out of view
                currentIndex = index;
                pressX = mouseX;
                pressY = mouseY;
                dragged = false;
            }

            onPositionChanged: {
                if (!dragged && (Math.abs(pressX-mouseX) > 5 || Math.abs(pressY-mouseY) > 5)) {
                    dragged = true;
                }
            }

            onReleased: {
                console.log("============= launcherItem onReleased folderIndex " +folderIndex
                            + "   rootFolder  "+rootFolder);
                if (folderIndex >= 0) {
                    //TODO create folder or move item to folder
                    console.log("============= launcherItem onReleased create folder or move item to folder");
                    folderIndex = -1;
                }
                cancelReordering();
            }

            onCanceled: {
                console.log("============= launcherItem onCanceled");
                cancelReordering();
            }

            Behavior on scale {
                NumberAnimation { easing.type: Easing.InOutQuad; duration: 150 }
            }

            ParallelAnimation {
                id: slideMoveAnim
                NumberAnimation { target: launcherItem; property: "x"; to: wrapper.x; duration: 150; easing.type: Easing.InOutQuad }
                NumberAnimation { target: launcherItem; property: "y"; to: wrapper.y; duration: 150; easing.type: Easing.InOutQuad }
            }

            SequentialAnimation {
                id: fadeMoveAnim
                NumberAnimation { target: launcherItem; property: "opacity"; to: 0; duration: 75 }
                ScriptAction { script: { launcherItem.x = wrapper.x; launcherItem.y = wrapper.y } }
                NumberAnimation { target: launcherItem; property: "opacity"; to: 1.0; duration: 75 }
            }
        }
    }
}
