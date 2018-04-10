//
//  Lyrics.swift
//  LrcShow
//
//  Created by Masahiro Kiyota on 2016/07/16.
//  Copyright © 2016 Juzbox. All rights reserved.
//

import Foundation

enum LyricsKind: String {
    case karaoke = "kra"
    case synced = "lrc"
    case unsynced = "txt"
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
        range = NSMakeRange(p, s.count)
    }
    
    convenience init(text s: String, startPos p: Int) {
        self.init(text: s, timeCode: 0, startPos: p)
    }
    
    convenience init(line s: String, match m: NSTextCheckingResult, startPos p: Int) {
        // [mm:ss:cc]text
        let nsS = s as NSString
        let min = nsS.substring(with: m.range(at: 1))
        let sec = nsS.substring(with: m.range(at: 2))
        let cenSec = nsS.substring(with: m.range(at: 3))
        let text = nsS.substring(with: m.range(at: 4))
        var time: Double = 0.0
        time += 60 * Double(min)!
        time += Double(sec)!
        time += 0.01 * Double(cenSec)!
        self.init(text: text, timeCode: time, startPos: p)
    }
}

class LyricsLine: LyricsChunk {
    var elements: [LyricsElement]
    
    init?(karaokeLine line:String, startPos p: Int) {
        elements = []
        let re = try! NSRegularExpression(pattern: "\\[(\\d{2}):(\\d{2}):(\\d{2})\\]([^\\[]*)", options: [])
        let matches = re.matches(in: line, options: [], range: NSMakeRange(0, line.count))
        if matches.count == 0 {
            return nil
        }
        var cur = p
        for match in matches {
            let elem = LyricsElement(line: line, match: match, startPos: cur)
            elements.append(elem)
            cur += elem.text.count
        }
    }
    
    init?(syncedLine line: String, startPos p: Int) {
        elements = []
        let re = try! NSRegularExpression(pattern: "^\\[(\\d{2}):(\\d{2}):(\\d{2})\\](.*)$", options: [])
        let match = re.firstMatch(in: line, options: [], range: NSMakeRange(0, line.count))
        if let match = match {
            elements.append(LyricsElement(line: line, match: match, startPos: p))
        } else {
            return nil
        }
        
    }
    
    init(unsyncedLine line: String) {
        elements = []
        elements.append(LyricsElement(text: line, startPos: 0))
    }
    
    var text: String {
        return elements.map{ $0.text }.joined(separator: "")
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
    var _text: String?

    var text: String {
        if _text == nil {
            _text = lines.map{ $0.text }.joined(separator: "\n")
        }
        return _text!
    }
    
    init(file fileURL: URL) {
        rawContent = try! String.init(contentsOf: fileURL)
        lines = []
        searchIndex = []
        _text = nil
    }
    
    class func lyricsForMusicFileURL(_ musicFileURL: URL) -> LyricsFile? {
        let pathWoExt: NSString = (musicFileURL.path as NSString).deletingPathExtension as NSString
        let fm = FileManager.default
        for ext in [LyricsKind.karaoke, LyricsKind.synced, LyricsKind.unsynced] {
            let candidatePath = pathWoExt.appendingPathExtension(ext.rawValue)!
            if (fm.fileExists(atPath: candidatePath)) {
                switch ext {
                case .karaoke:
                    return KaraokeLyricsFile(file: URL(fileURLWithPath: candidatePath))
                case .synced:
                    return SyncedLyricsFile(file: URL(fileURLWithPath: candidatePath))
                    
                case .unsynced:
                    return UnsyncedLyricsFile(file: URL(fileURLWithPath: candidatePath))
                }
            }
        }
        return nil
    }
    var kind: LyricsKind { return .unsynced }
    
    func position(time target: Double) -> LyricsPosition {
        if kind == .unsynced {
            return (0, 0, 0)
        }
        if searchIndex.count < 1 || target < searchIndex[0].0 {
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
        if kind == .synced {
            return (lineIndex, elemIndex, 0)
        }
        // Karaoke
        let elem = lines[lineIndex].elements[elemIndex]
        let start = elem.timeCode
        var charIndex = 0
        if elemIndex < lines[lineIndex].elements.count - 1 {
            let nextElem = lines[lineIndex].elements[elemIndex + 1]
            let end = nextElem.timeCode
            let timePerChar = (end - start) / Double(elem.text.count)
            charIndex = Int((target - start) / timePerChar)
        } else if lineIndex < lines.count - 1 { // last element in current line
            let nextElem = lines[lineIndex + 1].elements[0]
            let end = nextElem.timeCode
            let timePerChar = (end - start) / Double(elem.text.count)
            charIndex = Int((target - start) / timePerChar)
        } else { // last element of the whole lyrics
            charIndex = 0
        }
        return (lineIndex, elemIndex, charIndex)
    }
    
    func marking(position pos: LyricsPosition) -> LyricsMarking {
        var res: LyricsMarking
        let endPos = text.count
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
        if kind == .karaoke {
            let elem = line.elements[pos.elem]
            let offset = pos.char
            res.finishedChunkInCurrentLine = NSMakeRange(line.range.location, elem.range.location - line.range.location + offset)
            res.futureChunkInCurrentLine = NSMakeRange(elem.range.location + offset, line.range.length - (elem.range.location - line.range.location + offset))
        }
        return res
    }
}

class KaraokeLyricsFile: LyricsFile {
    override init(file fileURL: URL) {
        super.init(file: fileURL)
        var p = 0
        for rawLine in rawContent.components(separatedBy: "\n") {
            let line = LyricsLine(karaokeLine: rawLine, startPos: p)
            if let line = line {
                lines.append(line)
                p += line.text.count
                p += 1 // new line
            }
        }
        for (i, line) in lines.enumerated() {
            for (j, elem) in line.elements.enumerated() {
                searchIndex.append((elem.timeCode, i, j))
            }
        }
    }
    
    override var kind: LyricsKind { return .karaoke }
}

class SyncedLyricsFile: LyricsFile {
    override init(file fileURL: URL) {
        super.init(file: fileURL)
        var p = 0
        for rawLine in rawContent.components(separatedBy: "\n") {
            let line = LyricsLine(syncedLine: rawLine, startPos: p)
            if let line = line {
                lines.append(line)
                p += line.text.count
                p += 1 // new line
            }
        }
        for (i, line) in lines.enumerated() {
            searchIndex.append((line.timeCode, i, 0))
        }
    }
    
    override var kind: LyricsKind { return .synced }
}

class UnsyncedLyricsFile: LyricsFile {
    override init(file fileURL: URL) {
        super.init(file: fileURL)
        for line in rawContent.components(separatedBy: "\n") {
            lines.append(LyricsLine(unsyncedLine: line))
        }
    }
    
    override var kind: LyricsKind { return .unsynced }
}


