//
//  AppDelegate.swift
//  LrcShow
//
//  Created by Masahiro Kiyota on 2016/07/16.
//  Copyright © 2016 Juzbox. All rights reserved.
//

import Cocoa

let PollingInterval = 1.0
let PlayingInterval = 0.1
let AnimationDuration = 0.5

enum AppState {
    case polling
    case playback
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var iTunes: PlayerWrapper?
    var state: AppState = .polling
    var timer: Timer?
    var databaseID: Int = -1
    var lyrics: LyricsFile?
    var prevPlayTime: Double = -1
    var prevPlayTimeDate: Date?
    var prevPosition: LyricsPosition?
    var prevPositionScroll: LyricsPosition?
    
    @IBOutlet weak var window: NSPanel!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var visualEffectView: NSVisualEffectView!
    @IBOutlet var lyricsTextView: NSTextView!

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if #available(macOS 10.14, *) {
            // Need to deal w/ AppleEvent sandboxing
            var appBundle: String
            if #available(macOS 10.15, *) {
                appBundle = "com.apple.Music"
            } else {
                appBundle = "com.apple.iTunes"
            }
            let targetAEDescriptor = NSAppleEventDescriptor(bundleIdentifier: appBundle)
            let status = AEDeterminePermissionToAutomateTarget(targetAEDescriptor.aeDesc, typeWildCard, typeWildCard, true)
            
            if status != noErr {
                let alert = NSAlert()
                alert.messageText = "AppleEvent Authentication failed"
                alert.alertStyle = .warning
                alert.runModal()
                NSApp.terminate(self)
                return
            }
        }
        
        iTunes = PlayerWrapper.sharedInstance()!
        
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        if #available(macOS 10.14, *) {
            visualEffectView.material = .sheet
        } else {
            visualEffectView.material = .dark
        }

        window.level = .floating
        self.transit(state: .polling)
    }
    
    func transit(state newState:AppState) {
        if let timer = timer {
            timer.invalidate()
        }
        state = newState
        var interval: Double
        var sel: Selector
        switch (state) {
        case .polling:
            interval = PollingInterval
            sel = #selector(self.polling(_:))
        case .playback:
            interval = PlayingInterval
            sel = #selector(self.playing(_:))
        }
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: sel, userInfo: nil, repeats: true)
    }
    
    @objc func polling(_ t: Timer) {
        if iTunes?.state() != .stopped {
            t.invalidate()
            self.timer = nil
            trackChanged()
            transit(state: .playback)
        }
    }
    
    @objc func playing(_ t: Timer) {
        guard let iTunes = iTunes else { return }
        let playerState = iTunes.state()
        if playerState == .stopped {
            timer?.invalidate()
            timer = nil
            window.title = "Stopped"
            lyricsTextView.string = ""
            transit(state: .polling)
        } else {
            let dbID = iTunes.databaseID()
            if databaseID != dbID {
                trackChanged()
                return
            }
            if let lyrics = lyrics , lyrics.kind != .unsynced {
                var time = iTunes.playerPosition()
                if playerState == .playing && time == prevPlayTime { // not updated though playback is on the way
                    let diff = prevPlayTimeDate!.timeIntervalSinceNow
                    time -= diff
                } else { // updated
                    prevPlayTime = time
                    prevPlayTimeDate = Date()
                }
                let pos = lyrics.position(time: time)
                let posScroll = lyrics.position(time: time + AnimationDuration / 2)
                if prevPositionScroll == nil || (prevPositionScroll != nil && posScroll.line != prevPositionScroll!.line) {
                    scroll(toLine: posScroll.line)
                    prevPositionScroll = posScroll
                }
                if prevPosition == nil || (prevPosition != nil && pos != prevPosition!) {
                    let marking = lyrics.marking(position: pos)
                    lyricsTextView.textStorage?.addAttributes([.foregroundColor: NSColor.gray], range: marking.finishedLines)
                    lyricsTextView.textStorage?.addAttributes([.foregroundColor: NSColor.orange], range: marking.currentLine)
                    lyricsTextView.textStorage?.addAttributes([.foregroundColor: NSColor.white], range: marking.futureLines)
                    if lyrics.kind == .karaoke {
                        lyricsTextView.textStorage?.addAttributes([.foregroundColor: NSColor.gray], range: marking.finishedChunkInCurrentLine)
                   }
                    prevPosition = pos
                }
            }
        }
    }
    
    func trackChanged() {
        guard let iTunes = iTunes else { return }
        window.title = iTunes.trackDescription()!
        databaseID = iTunes.databaseID()
        let url: URL? = iTunes.location()
        lyrics = url != nil ? LyricsFile.lyricsForMusicFileURL(url!) : nil;
        if let lyrics = lyrics {
            lyricsTextView.string = lyrics.text
            lyricsTextView.textColor = .white
        } else {
            lyricsTextView.string = ""
        }
        prevPlayTime = -1
        prevPlayTimeDate = nil
    }
    
    func scroll(toLine lineNo: Int) {
        let clipView = scrollView.contentView
        let clipHeight = scrollView.frame.size.height
        let textHeight = clipView.documentRect.size.height
        
        if clipHeight >= textHeight {
            // whole text is displayed
            return
        }
        
        let lines = lyrics!.lines.count
        let lineHeight = textHeight / CGFloat(lines)
        let halfLine = Int(clipHeight / lineHeight / 2)
        var to: CGFloat
        if lineNo <= halfLine {
            to = 0.0
        } else if lineNo + halfLine >= lines {
            to = textHeight - clipHeight
        } else {
            to = lineHeight * CGFloat(lineNo) - clipHeight / 2
        }
        var origin = clipView.bounds.origin
        if origin.y != to {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = AnimationDuration
            origin.y = to
            clipView.animator().setBoundsOrigin(origin)
            NSAnimationContext.endGrouping()
        }
    }
}
