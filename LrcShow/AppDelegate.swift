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
    case Polling
    case Playback
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let iTunes = iTunesWrapper.sharedInstance()!
    var state: AppState = .Polling
    var timer: NSTimer?
    var databaseID: Int = -1
    var lyrics: LyricsFile?
    var prevPlayTime: Double = -1
    var prevPlayTimeDate: NSDate?
    var prevPosition: LyricsPosition?
    
    @IBOutlet weak var window: NSPanel!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet var lyricsTextView: NSTextView!

    func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationDidFinishLaunching(notification: NSNotification) {
        window.level = Int(CGWindowLevelForKey(CGWindowLevelKey.NormalWindowLevelKey))
        self.transit(state: .Polling)
    }
    
    func transit(state newState:AppState) {
        if let timer = timer {
            timer.invalidate()
        }
        state = newState
        var interval: Double
        var sel: Selector
        switch (state) {
        case .Polling:
            interval = PollingInterval
            sel = #selector(self.polling(_:))
        case .Playback:
            interval = PlayingInterval
            sel = #selector(self.playing(_:))
        }
        timer = NSTimer.scheduledTimerWithTimeInterval(interval, target: self, selector: sel, userInfo: nil, repeats: true)
    }
    
    func polling(_ t: NSTimer) {
        if iTunes.state() != .Stopped {
            t.invalidate()
            self.timer = nil
            trackChanged()
            transit(state: .Playback)
        }
    }
    
    func playing(_ t: NSTimer) {
        let playerState = iTunes.state()
        if playerState == .Stopped {
            timer?.invalidate()
            timer = nil
            window.title = "Stopped"
            lyricsTextView.string = ""
            transit(state: .Polling)
        } else {
            let dbID = iTunes.databaseID()
            if databaseID != dbID {
                trackChanged()
                return
            }
            if let lyrics = lyrics where lyrics.kind != .Unsynced {
                var time = iTunes.playerPosition()
                if playerState == .Playing && time == prevPlayTime { // not updated though playback is on the way
                    let diff = prevPlayTimeDate!.timeIntervalSinceNow
                    time -= diff
                } else { // updated
                    prevPlayTime = time
                    prevPlayTimeDate = NSDate()
                }
                let pos = lyrics.position(time: time)
                if prevPosition == nil || (prevPosition != nil && pos != prevPosition!) {
                    if prevPosition == nil || (pos.line != prevPosition!.line) {
                        scroll(toLine: pos.line)
                    }
                    let marking = lyrics.marking(position: pos)
                    lyricsTextView.textStorage?.addAttributes([NSForegroundColorAttributeName: NSColor.grayColor()], range: marking.finishedLines)
                    lyricsTextView.textStorage?.addAttributes([NSForegroundColorAttributeName: NSColor.orangeColor()], range: marking.currentLine)
                    lyricsTextView.textStorage?.addAttributes([NSForegroundColorAttributeName: NSColor.whiteColor()], range: marking.futureLines)
                    if lyrics.kind == .Karaoke {
                        lyricsTextView.textStorage?.addAttributes([NSForegroundColorAttributeName: NSColor.grayColor()], range: marking.finishedChunkInCurrentLine)
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
            lyricsTextView.textColor = NSColor.whiteColor()
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
        NSAnimationContext.currentContext().duration = AnimationDuration
        var origin = clipView.bounds.origin
        origin.y = to
        clipView.animator().setBoundsOrigin(origin)
        NSAnimationContext.endGrouping()
    }
}
