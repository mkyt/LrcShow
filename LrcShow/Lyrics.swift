//
//  Lyrics.swift
//  LrcShow
//
//  Created by 清田正紘 on 2016/07/16.
//  Copyright © 2016年 Juzbox. All rights reserved.
//

import Foundation

enum LyricsKind: String {
    case Karaoke = "kra"
    case Synced = "lrc"
    case Unsynced = "txt"
}


/*
 Lyrics line and element (collectively denoted as chunk)
 */
protocol LyricsChunk {
    var text: String { get }
    var timeCode: Double { get }
}

class LyricsElement: LyricsChunk {
    var text: String
    var timeCode: Double
    var range: NSRange
    
    init(text s: String, timeCode c: Double, startPos p: Int) {
        text = s
        timeCode = c
        range = NSMakeRange(p, s.characters.count)
    }
    
    convenience init(text s: String, startPos p: Int) {
        self.init(text: s, timeCode: 0, startPos: p)
    }
    
    convenience init(line s: String, match m: NSTextCheckingResult, startPos p: Int) {
        // [mm:ss:cc]text
        let nsS = s as NSString
        let min = nsS.substringWithRange(m.rangeAtIndex(1))
        let sec = nsS.substringWithRange(m.rangeAtIndex(2))
        let cenSec = nsS.substringWithRange(m.rangeAtIndex(3))
        let text = nsS.substringWithRange(m.rangeAtIndex(4))
        var time: Double = 0.0
        time += 60 * Double(min)!
        time += Double(sec)!
        time += 0.01 * Double(cenSec)!
        self.init(text: text, timeCode: time, startPos: p)
    }
}

class LyricsLine: LyricsChunk {
    var elements: [LyricsElement]
    init(karaokeLine line:String, startPos p: Int) {
        elements = []
        let re = try! NSRegularExpression(pattern: "\\[(\\d{2}):(\\d{2}):(\\d{2})\\]([^\\[]*)", options: [])
        let matches = re.matchesInString(line, options: [], range: NSMakeRange(0, line.characters.count))
        var cur = p
        for match in matches {
            let elem = LyricsElement(line: line, match: match, startPos: cur)
            elements.append(elem)
            cur += elem.text.characters.count
        }
    }
    init(syncedLine line: String, startPos p: Int) {
        elements = []
        let re = try! NSRegularExpression(pattern: "^\\[(\\d{2}):(\\d{2}):(\\d{2})\\](.*)$", options: [])
        let match = re.firstMatchInString(line, options: [], range: NSMakeRange(0, line.characters.count))!
        elements.append(LyricsElement(line: line, match: match, startPos: p))
    }
    init(unsyncedLine line: String) {
        elements = []
        elements.append(LyricsElement(text: line, startPos: 0))
    }
    var text: String {
        return elements.map{ $0.text }.joinWithSeparator("")
    }
    var timeCode: Double {
        if elements.count == 0 {
            return 0
        } else {
            return elements[0].timeCode
        }
    }
    var range: NSRange {
        if elements.count == 0 {
            return NSMakeRange(0, 0)
        } else {
            let firstElemRange = elements[0].range
            let lastElemRange = elements[elements.count - 1].range
            return NSMakeRange(firstElemRange.location,
              lastElemRange.location + lastElemRange.length - firstElemRange.location)
        }
    }
}

/*
 Lyrics file object
 */
typealias LyricsPosition = (line: Int, elem: Int, char: Int)
typealias LyricsMarking = (
    finishedLines: NSRange,
    currentLine: NSRange,
    finishedChunkInCurrentLine: NSRange,
    futureChunkInCurrentLine: NSRange,
    futureLines: NSRange
)
typealias SearchIndexEntry = (Double, Int, Int)

class LyricsFile {
    var rawContent: String
    var lines: [LyricsLine]
    var searchIndex: [SearchIndexEntry]
    var text: String {
        return lines.map{ $0.text }.joinWithSeparator("\n")
    }
    
    init(file fileURL: NSURL) {
        rawContent = try! String.init(contentsOfURL: fileURL)
        lines = []
        searchIndex = []
    }
    
    class func lyricsForMusicFileURL(_ musicFileURL: NSURL) -> LyricsFile? {
        let pathWoExt: NSString = (musicFileURL.path! as NSString).stringByDeletingPathExtension
        let fm = NSFileManager.defaultManager()
        for ext in [LyricsKind.Karaoke, LyricsKind.Synced, LyricsKind.Unsynced] {
            let candidatePath = pathWoExt.stringByAppendingPathExtension(ext.rawValue)!
            if (fm.fileExistsAtPath(candidatePath)) {
                switch ext {
                case .Karaoke:
                    return KaraokeLyricsFile(file: NSURL.fileURLWithPath(candidatePath))
                case .Synced:
                    return SyncedLyricsFile(file: NSURL.fileURLWithPath(candidatePath))
                    
                case .Unsynced:
                    return UnsyncedLyricsFile(file: NSURL.fileURLWithPath(candidatePath))
                }
            }
        }
        return nil
    }
    var kind: LyricsKind { return .Unsynced }
    
    func position(time target: Double) -> LyricsPosition {
        if kind == .Unsynced {
            return (0, 0, 0)
        }
        if target < searchIndex[0].0 {
            return (-1, 0, 0)
        }
        var lo = 0, hi = searchIndex.count
        while hi - lo > 1 {
            let mid = Int((hi + lo) / 2)
            let t = searchIndex[mid].0
            if t > target {
                hi = mid
            } else {
                lo = mid
            }
        }
        let lineIndex = searchIndex[lo].1
        let elemIndex = searchIndex[lo].2
        if kind == .Synced {
            return (lineIndex, elemIndex, 0)
        }
        // Karaoke
        let elem = lines[lineIndex].elements[elemIndex]
        let start = elem.timeCode
        var charIndex = 0
        if elemIndex < lines[lineIndex].elements.count - 1 {
            let nextElem = lines[lineIndex].elements[elemIndex + 1]
            let end = nextElem.timeCode
            let timePerChar = (end - start) / Double(elem.text.characters.count)
            charIndex = Int((target - start) / timePerChar)
        } else if lineIndex < lines.count - 1 { // last element in current line
            let nextElem = lines[lineIndex + 1].elements[0]
            let end = nextElem.timeCode
            let timePerChar = (end - start) / Double(elem.text.characters.count)
            charIndex = Int((target - start) / timePerChar)
        } else { // last element of the whole lyrics
            charIndex = 0
        }
        return (lineIndex, elemIndex, charIndex)
    }
    
    func marking(position pos: LyricsPosition) -> LyricsMarking {
        var res: LyricsMarking
        let endPos = text.characters.count
        if pos.line < 0 {
            res.finishedLines = NSMakeRange(0, 0)
            res.currentLine = NSMakeRange(0, 0)
            res.futureLines = NSMakeRange(0, endPos)
            res.finishedChunkInCurrentLine = NSMakeRange(0, 0)
            res.futureChunkInCurrentLine = NSMakeRange(0, 0)
            return res
        }
        let line = lines[pos.line]
        res.finishedLines = NSMakeRange(0, line.range.location)
        res.currentLine = line.range
        let futureLineStart = line.range.location + line.range.length
        res.futureLines = NSMakeRange(futureLineStart, endPos - futureLineStart)
        res.finishedChunkInCurrentLine = NSMakeRange(0, 0)
        res.futureChunkInCurrentLine = NSMakeRange(0, 0)
        if kind == .Karaoke {
            let elem = line.elements[pos.elem]
            let offset = pos.char
            res.finishedChunkInCurrentLine = NSMakeRange(line.range.location, elem.range.location - line.range.location + offset)
            res.futureChunkInCurrentLine = NSMakeRange(elem.range.location + offset, line.range.length - (elem.range.location - line.range.location + offset))
        }
        print("position:")
        print(res)
        return res
    }
}

class KaraokeLyricsFile: LyricsFile {
    override init(file fileURL: NSURL) {
        super.init(file: fileURL)
        var p = 0
        for rawLine in rawContent.componentsSeparatedByString("\n") {
            let line = LyricsLine(karaokeLine: rawLine, startPos: p)
            lines.append(line)
            p += line.text.characters.count
            p += 1 // new line
        }
        for (i, line) in lines.enumerate() {
            for (j, elem) in line.elements.enumerate() {
                searchIndex.append((elem.timeCode, i, j))
            }
        }
    }
    
    override var kind: LyricsKind { return .Karaoke }
}

class SyncedLyricsFile: LyricsFile {
    override init(file fileURL: NSURL) {
        super.init(file: fileURL)
        var p = 0
        for rawLine in rawContent.componentsSeparatedByString("\n") {
            let line = LyricsLine(syncedLine: rawLine, startPos: p)
            lines.append(line)
            p += line.text.characters.count
            p += 1 // new line
        }
        for (i, line) in lines.enumerate() {
            searchIndex.append((line.timeCode, i, 0))
        }
    }
    
    override var kind: LyricsKind { return .Synced }
}

class UnsyncedLyricsFile: LyricsFile {
    override init(file fileURL: NSURL) {
        super.init(file: fileURL)
        for line in rawContent.componentsSeparatedByString("\n") {
            lines.append(LyricsLine(unsyncedLine: line))
        }
    }
    
    override var kind: LyricsKind { return .Unsynced }
}


