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

    let iTunes = iTunesWrapper.sharedInstance()!
    var state: AppState = .polling
    var timer: Timer?
    var databaseID: Int = -1
    var lyrics: LyricsFile?
    var prevPlayTime: Double = -1
    var prevPlayTimeDate: Date?
    var prevPosition: LyricsPosition?
    
    @IBOutlet weak var window: NSPanel!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet var lyricsTextView: NSTextView!

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window.level = Int(CGWindowLevelForKey(CGWindowLevelKey.normalWindow))
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
    
    func polling(_ t: Timer) {
        if iTunes.state() != .stopped {
            t.invalidate()
            self.timer = nil
            trackChanged()
            transit(state: .playback)
        }
    }
    
    func playing(_ t: Timer) {
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
                if prevPosition == nil || (prevPosition != nil && pos != prevPosition!) {
                    if prevPosition == nil || (pos.line != prevPosition!.line) {
                        scroll(toLine: pos.line)
                    }
                    let marking = lyrics.marking(position: pos)
                    lyricsTextView.textStorage?.addAttributes([NSForegroundColorAttributeName: NSColor.gray], range: marking.finishedLines)
                    lyricsTextView.textStorage?.addAttributes([NSForegroundColorAttributeName: NSColor.orange], range: marking.currentLine)
                    lyricsTextView.textStorage?.addAttributes([NSForegroundColorAttributeName: NSColor.white], range: marking.futureLines)
                    if lyrics.kind == .karaoke {
                        lyricsTextView.textStorage?.addAttributes([NSForegroundColorAttributeName: NSColor.gray], range: marking.finishedChunkInCurrentLine)
                   }
                    prevPosition = pos
                }
                
            }
        }
    }
    
    func trackChanged() {
        window.title = iTunes.trackDescription()!
        databaseID = iTunes.databaseID()
        let url = iTunes.location()!
        lyrics = LyricsFile.lyricsForMusicFileURL(url)
        if let lyrics = lyrics {
            lyricsTextView.string = lyrics.text
            lyricsTextView.textColor = NSColor.white
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
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current().duration = AnimationDuration
        var origin = clipView.bounds.origin
        origin.y = to
        clipView.animator().setBoundsOrigin(origin)
        NSAnimationContext.endGrouping()
    }
}
