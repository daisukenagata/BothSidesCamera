//
//  ContentView.swift
//  BothSidesCamera
//
//  Created by 永田大祐 on 2019/11/26.
//  Copyright © 2019 永田大祐. All rights reserved.
//

import SwiftUI
import BothSidesCamera

struct ContentView: View {

    @State var bView = SidesView()
    @State var didTap: Bool = false
    @State var selectorIndex = 0

    @State private var margin: CGFloat = 10

    @EnvironmentObject var model: OrientationModel

    var body: some View {
        VStack {
            bView
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)

            HStack {
                Button(
                    action: {
                        self.bView.screenShot()
                },
                    label: {
                        Text("")
                            .frame(width: 50, height: 50)
                            .imageScale(.large)
                            .background(Color.gray)
                            .clipShape(Circle())
                }
                ).padding(.top, margin)
                    .padding(.leading, margin)
                    .padding(.trailing, margin)
                    .alert(isPresented: $model.showingAlert) {
                    Alert(title: Text("Save Screen"))
                }

                Button(
                    action: {
                        self.didTap = self.didTap ? false : true
                        self.bView.cameraStart()
                },
                    label: {
                        Text("")
                            .padding(margin)
                            .frame(width: 50, height: 50)
                            .imageScale(.large)
                            .background(didTap ? Color.red : Color.white)
                            .clipShape(Circle())
                }
                ).padding(.top, margin)
                    .padding(.leading, margin)
                    .padding(.trailing, margin)

                Button(
                    action: {
                        let index = self.selectorIndex == 0 ? 1 : 0
                        self.selectorIndex = index
                        _ = self.bView.changeDviceType(self.bView.bothSidesView,numbers: self.selectorIndex)
                },
                    label: {
                        Text("")
                            .frame(width: 50, height: 50)
                            .imageScale(.large)
                            .background(Color.blue)
                            .clipShape(Circle())
                }
                ).padding(.top, margin)
                    .padding(.leading, margin)
                    .padding(.trailing, margin)

                Button(
                    action: {
                         self.bView.sameRatioFlg()
                },
                    label: {
                        Text("")
                            .frame(width: 50, height: 50)
                            .imageScale(.large)
                            .background(Color.purple)
                            .clipShape(Circle())
                }
                ).padding(.top, margin)
                    .padding(.leading, margin)
                    .padding(.trailing, margin)

                Button(
                    action: {
                         self.bView.flash()
                },
                    label: {
                        Text("")
                            .frame(width: 50, height: 50)
                            .imageScale(.large)
                            .background(Color.yellow)
                            .clipShape(Circle())
                }
                ).padding(.top, margin)
                    .padding(.leading, margin)
                    .padding(.trailing, margin)

            }.onAppear {
                self.model.contentView = self
                self.bView.orientationModel = self.model
                _ = self.bView.changeDviceType(self.bView.bothSidesView,numbers: self.selectorIndex)

                guard let backCameraVideoPreviewView = self.bView.bothSidesView.backCameraVideoPreviewView else { return }

                // preview orign set example
                backCameraVideoPreviewView.videoPreviewLayer.frame = CGRect(x: 0,
                                                                            y: 0,
                                                                            width : backCameraVideoPreviewView.frame.width,
                                                                            height: backCameraVideoPreviewView.frame.width * 1.77777777777778)
                self.bView.bothSidesView.deviceAspect(rect: backCameraVideoPreviewView.frame)
                self.bView.bothSidesView.resetAspect()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct SidesView: UIViewRepresentable {

    var orientationModel: OrientationModel?
    @State var bothSidesView = BothSidesView(backDeviceType: .builtInUltraWideCamera,
                                             frontDeviceType: .builtInWideAngleCamera)

    func saveBtn() {
        DispatchQueue.main.async {
            self.orientationModel?.showingAlert = true
        }
    }

    // Super wide angle compatible
    func changeDviceType(_ bView: BothSidesView, numbers: Int) -> ContentView? {
        numbers == 0 ?
            bView.changeDviceType(backDeviceType: .builtInWideAngleCamera, frontDeviceType:.builtInWideAngleCamera) :
            bView.changeDviceType(backDeviceType: .builtInUltraWideCamera, frontDeviceType:.builtInWideAngleCamera)
        return nil
    }

    // Modifying state during view update, this will cause undefined behavior.  bothSidesView = bView
    func updateUIView(_ bView: BothSidesView, context: Context) {
        DispatchQueue.main.async { self.bothSidesView = bView }
    }

    func flash() { bothSidesView.pushFlash() }

    func cameraStop() { bothSidesView.cameraStop()}
    
    func sameRatioFlg() {bothSidesView.sameRatioFlg()}
    
    func screenShot() { bothSidesView.screenShot(call: saveBtn)}

    func cameraStart() { bothSidesView.cameraMixStart(completion: saveBtn) }

    func makeUIView(context: UIViewRepresentableContext<SidesView>) -> BothSidesView { return  bothSidesView }

    func orientation(model: OrientationModel) { bothSidesView.preViewSizeSet(orientation:  model.orientation) }

}

final class OrientationModel: ObservableObject {

    @Published var showingAlert = false
    @Published var orientation: UIInterfaceOrientation = .unknown

    var contentView: ContentView?

    private var notificationCenter: NotificationCenter

    init(center: NotificationCenter = .default) {
        notificationCenter = center
        notificationCenter.addObserver( self, selector: #selector(foreGround), name: UIApplication.willEnterForegroundNotification,object: nil)
        notificationCenter.addObserver( self, selector: #selector(backGround), name: UIApplication.didEnterBackgroundNotification,object: nil)
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    @objc func foreGround(notification: Notification) {
        guard let contentView = contentView else { return }
        contentView.bView.bothSidesView.resetAspect()
        contentView.bView.cameraStart()
    }

    @objc func backGround(notification: Notification) {
        guard let contentView = contentView else { return }
        contentView.didTap = false
        contentView.bView.cameraStop()
    }

}
