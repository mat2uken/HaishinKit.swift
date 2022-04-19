//
//  LocalStream.swift
//  HaishinKit
//
//  Created by mat2uken on 2022/04/18.
//  Copyright © 2022 Shogo Endo. All rights reserved.
//

import Foundation

open class LocalStream: NetStream {
    var resourceName: String?

    open private(set) var recording: Bool = false {
        didSet {
            print("recording: ", recording)
            guard oldValue != recording else {
                return
            }

            if oldValue {
                // was recording
                #if os(iOS)
                    mixer.videoIO.screen?.stopRunning()
                #endif
                mixer.audioIO.codec.stopRunning()
                mixer.videoIO.encoder.stopRunning()
                mixer.recorder.stopRunning()
                mixer.recorder.finishWriting()
            }

            if recording {
                #if os(iOS)
                    mixer.videoIO.screen?.startRunning()
                #endif
                mixer.startRunning()
                mixer.audioIO.codec.startRunning()
                mixer.videoIO.encoder.startRunning()
                mixer.recorder.fileName = resourceName
                mixer.recorder.startRunning()
            }
        }
    }

    var paused: Bool = false

    deinit {
        mixer.stopRunning()
    }

    open func record(_ name: String?) {
        lockQueue.async {
            guard let name: String = name else {
                if self.recording {
                    self.recording = false
                }
                return
            }

            self.resourceName = name
            self.recording = true
        }
    }

    open func close() {
        if !recording {
            return
        }
        //record(nil)
        lockQueue.sync {
            self.recording = false
        }
    }

    open func pause() {
        lockQueue.async {
            self.paused = true
            if self.recording {
                self.mixer.audioIO.codec.muted = true
            }
        }
    }

    open func resume() {
        lockQueue.async {
            self.paused = false
            if self.recording {
                self.mixer.audioIO.codec.muted = false
                self.mixer.videoIO.encoder.muted = false
            }
        }
    }

    open func togglePause() {
        lockQueue.async {
            if self.recording {
                self.paused = !self.paused
                self.mixer.audioIO.codec.muted = self.paused
                self.mixer.videoIO.encoder.muted = self.paused
            }
        }
    }
}
