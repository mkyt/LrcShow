//
//  LSLyrics.m
//  LrcShow
//
//  Created by Hiro on 4/19/15.
//  Copyright (c) 2015 Juzbox. All rights reserved.
//

#import "LSLyrics.h"

@interface LSLyricsElement ()

@property (nonatomic, strong) NSString *stringHolder;

@end

@implementation LSLyricsElement

- (instancetype)initWithCharactersNoCopy:(unichar *)characters length:(NSUInteger)length freeWhenDone:(BOOL)freeBuffer {
    self = [super init];
    if (self) {
        self.stringHolder = [[NSString alloc] initWithCharactersNoCopy:characters length:length freeWhenDone:freeBuffer];
    }
    return self;
}

- (NSUInteger)length {
    return self.stringHolder.length;
}

- (unichar)characterAtIndex:(NSUInteger)index {
    return [self.stringHolder characterAtIndex:index];
}

+ (LSLyricsElement *)elementWithString:(NSString *)string timeCode:(double)time {
    return [[LSLyricsElement alloc] initWithString:string timeCode:time];
}

+ (LSLyricsElement *)elementWithString:(NSString *)string match:(NSTextCheckingResult *)match {
    NSString* min = [string substringWithRange:[match rangeAtIndex:1]];
    NSString* sec = [string substringWithRange:[match rangeAtIndex:2]];
    NSString* centiSec = [string substringWithRange:[match rangeAtIndex:3]];
    NSString* s = [string substringWithRange:[match rangeAtIndex:4]];
    NSNumberFormatter *fmtr = [[NSNumberFormatter alloc] init];
    [fmtr setNumberStyle:NSNumberFormatterDecimalStyle];
    double time = 0;
    time += 60. * [[fmtr numberFromString:min] intValue];
    time += [[fmtr numberFromString:sec] intValue];
    time +=  0.01 * [[fmtr numberFromString:centiSec] intValue];
    return [LSLyricsElement elementWithString:s timeCode:time];
}

- (instancetype)initWithString:(NSString *)string timeCode:(double)time {
    self = [super initWithString:string];
    if (self) {
        timeCode = time;
    }
    return self;
}

- (instancetype)initWithString:(NSString *)aString {
    self = [super initWithString:aString];
    if (self) {
        timeCode = -1;
    }
    return self;
}

@synthesize timeCode;
@synthesize range;

@end

@interface LSLyricsElements ()

@property (nonatomic, strong) NSMutableArray *arr;

@end

@implementation LSLyricsElements

- (instancetype)initWithContent:(LyricsElementsContent)_content {
    self = [super init];
    if (self) {
        content = _content;
        _arr = [NSMutableArray array];
    }
    return self;
}

- (void)insertObject:(id)object atIndex:(NSUInteger)index {
    return [_arr insertObject:object atIndex:index];
}

- (id)objectAtIndex:(NSUInteger)index {
    return [_arr objectAtIndex:index];
}

- (LSLyricsElement *)joinedElement {
    NSString *sep = @"";
    if (content == ContentLines) sep = @"\n";
    double time = -1;
    if ([self count] > 0) {
        LSLyricsElement *elem = [self objectAtIndex:0];
        time = [elem timeCode];
    }
    return [LSLyricsElement elementWithString:[self componentsJoinedByString:sep] timeCode:time];
}

- (NSString *)description {
    return [self joinedElement];
}

- (NSUInteger)count {
    return [_arr count];
}

- (double)timeCode {
    if ([_arr count] > 0) return [[_arr objectAtIndex:0] timeCode];
    else return -1;
}

@synthesize content;
@synthesize range;

@end


typedef struct elem_index_entry_s {
    double time;
    NSInteger line_idx;
    NSInteger elem_idx;
} elem_index_entry_t;

@implementation LSLyrics
{
    elem_index_entry_t *elem_index;
    NSUInteger elem_cnt;
    NSUInteger end_pos;
}
+ (LSLyrics *)lyricsWithMusicFileURL:(NSURL *)musicFileURL {
    NSString *pathWithoutExtension = [[musicFileURL path] stringByDeletingPathExtension];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *ext in @[@"kra", @"lrc", @"txt"]) {
        NSString *candidatePath = [pathWithoutExtension stringByAppendingPathExtension:ext];
        if ([fm fileExistsAtPath:candidatePath]) {
            return [[LSLyrics alloc] initWithLyricsFileURL:[NSURL fileURLWithPath:candidatePath]];
        }
    }
    return nil;
}

+ (LSLyrics *)lyricsWithLyricsFileURL:(NSURL *)fileURL {
    LSLyrics *res = [[LSLyrics alloc] initWithLyricsFileURL:fileURL];
    return res;
}

- (instancetype)initWithLyricsFileURL:(NSURL *)aFileURL {
    self = [super init];
    if (self) {
        fileURL = aFileURL;
        NSString *extension = [[fileURL path] pathExtension];
        if ([extension isEqualToString:@"kra"]) {
            kind = LyricsKindKaraoke;
        } else if ([extension isEqualToString:@"lrc"]) {
            kind = LyricsKindSynced;
        } else {
            kind = LyricsKindUnsynced;
        }
        lines = [[LSLyricsElements alloc] initWithContent:ContentLines];
        elem_index = NULL;
        [self loadLyrics];
    }
    return self;
}

- (void)dealloc {
    if (elem_index) free(elem_index);
}

- (void)loadLyrics {
    NSError* err;
    content = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:&err];
    switch (kind) {
        case LyricsKindKaraoke:
            [self parseKaraoke];
            break;
        case LyricsKindSynced:
            [self parseSynced];
            break;
        case LyricsKindUnsynced:
            [self parseUnsynced];
            break;
    }
}

- (void)parseKaraoke {
    NSError *err;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\[(\\d{2}):(\\d{2}):(\\d{2})\\]([^\\[]*)" options:0 error:&err];
    NSArray *_lines = [content componentsSeparatedByString:@"\n"];
    NSUInteger sol = 0; // start index of the current line
    for (NSString *line in _lines) {
        NSUInteger line_len = 0;
        LSLyricsElements *elems = [[LSLyricsElements alloc] initWithContent:ContentElements];
        NSArray *matches = [re matchesInString:line options:0 range:NSMakeRange(0, [line length])];
        NSUInteger soe = sol; // start index of the current element
        for (NSTextCheckingResult *match in matches) {
            LSLyricsElement *elem = [LSLyricsElement elementWithString:line match:match];
            NSUInteger len = [elem length];
            elem.range = NSMakeRange(soe, len);
            //NSLog(@"%@ loc:%ld len:%ld", elem, elem.range.location, elem.range.length);
            soe += len;
            line_len += len;
            elem_cnt++;
            [elems addObject:elem];
        }
        elems.range = NSMakeRange(sol, line_len);
        sol += line_len + 1; // + 1 for new line
        end_pos = sol - 1;
        [lines addObject:elems];
    }
    
    // build index
    elem_index = (elem_index_entry_t *)malloc(sizeof(elem_index_entry_t)*elem_cnt);
    NSUInteger cur = 0;
    for (NSUInteger line_idx = 0; line_idx < [lines count]; ++line_idx) {
        LSLyricsElements *elems = [lines objectAtIndex:line_idx];
        for (NSUInteger elem_idx = 0; elem_idx < [elems count]; ++elem_idx) {
            LSLyricsElement *elem = [elems objectAtIndex:elem_idx];
            elem_index_entry_t entry = { elem.timeCode, line_idx, elem_idx };
            elem_index[cur++] = entry;
        }
    }
}

- (void)parseSynced {
    NSError *err;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^\\[(\\d{2}):(\\d{2}):(\\d{2})\\](.*)$" options:0 error:&err];
    NSArray *_lines = [content componentsSeparatedByString:@"\n"];
    NSUInteger sol = 0;
    for (NSString *line in _lines) {
        NSTextCheckingResult *match = [re firstMatchInString:line options:0 range:NSMakeRange(0, [line length])];
        LSLyricsElement *elem = [LSLyricsElement elementWithString:line match:match];
        NSUInteger len = [elem length];
        elem.range = NSMakeRange(sol, len);
        sol += len + 1; // + 1 for new line
        end_pos = sol - 1;
        [lines addObject:elem];
    }
    elem_cnt = [lines count];
    elem_index = (elem_index_entry_t *)malloc(sizeof(elem_index_entry_t)*elem_cnt);
    for (NSUInteger line_idx = 0; line_idx < elem_cnt; ++line_idx) {
        LSLyricsElement *elem = [lines objectAtIndex:line_idx];
        elem_index_entry_t entry = { elem.timeCode, line_idx, -1 };
        elem_index[line_idx] = entry;
    }
}

- (void)parseUnsynced {
    NSArray *_lines = [content componentsSeparatedByString:@"\n"];
    for (NSString *line in _lines) {
        [lines addObject:[[LSLyricsElement alloc] initWithString:line]];
    }
}

- (BOOL)positionForTime:(double)time pos:(lyrics_pos_t *)pos {
    NSInteger lo = 0, hi = elem_cnt; // [lo, hi)
    elem_index_entry_t entry = {0, -1, -1};
    if (elem_cnt > 0 && elem_index[0].time < time) {
        while (hi - lo > 1) {
            NSUInteger mid = (hi + lo) / 2;
            double t = elem_index[mid].time;
            if (t > time) {
                hi = mid;
            } else {
                lo = mid;
            }
        }
        entry = elem_index[lo];
        //NSLog(@"time :%.3f, elem_time: %.3f line: %ld, elem: %ld", time, entry.time, entry.line_idx, entry.elem_idx);
    }
    NSUInteger char_idx = 0;
    if (kind == LyricsKindKaraoke && entry.line_idx >= 0 && entry.elem_idx >= 0) {
        LSLyricsElements *elems = lines[entry.line_idx];
        LSLyricsElement *elem = elems[entry.elem_idx];
        NSUInteger cnt = [elem length];
        double startTime = [elem timeCode];
        if (cnt > 1) {
            double nextTime = -1;
            if (entry.elem_idx < elems.count - 1) {
                LSLyricsElement *nextElem = elems[entry.elem_idx+1];
                nextTime = nextElem.timeCode;
            } else if (entry.line_idx < lines.count - 1) { // last elem in the current line
                LSLyricsElements *nextLine = lines[entry.line_idx+1];
                LSLyricsElement *nextElem = nextLine[0];
                nextTime = nextElem.timeCode;
            }
            if (nextTime >= time) {
                double durPerChar = (nextTime - startTime) / cnt;
                char_idx = (NSUInteger)((time - startTime) / durPerChar);
            }
        }
    }
    if (pos->elem_index != entry.elem_idx ||
        pos->line != entry.line_idx ||
        pos->char_index_in_elem != char_idx) {
        pos->elem_index = entry.elem_idx;
        pos->line = entry.line_idx;
        pos->char_index_in_elem = char_idx;
        return YES;
    } else {
        return NO;
    }
}

- (void)markingsForPos:(const lyrics_pos_t *)pos markings:(lyrics_marking_t *)markings {
    NSInteger line_idx = pos->line, elem_idx = pos->elem_index;
    if (line_idx < 0) {
        markings->finished_lines = NSMakeRange(0, 0);
        markings->current_line = NSMakeRange(0, 0);
        markings->future_lines = NSMakeRange(0, end_pos);
        markings->done_in_current_line = NSMakeRange(0, 0);
        markings->undone_in_current_line = NSMakeRange(0, 0);
        return;
    }
    if (kind == LyricsKindKaraoke) {
        LSLyricsElements *elems = [lines objectAtIndex:line_idx];
        NSRange cur_line_range = elems.range;
        markings->current_line = cur_line_range;
        markings->finished_lines = NSMakeRange(0, cur_line_range.location);
        
        NSUInteger future_start = cur_line_range.location + cur_line_range.length;
        markings->future_lines = NSMakeRange(future_start, end_pos - future_start);
        LSLyricsElement *elem = [elems objectAtIndex:elem_idx];
        NSUInteger offset = pos->char_index_in_elem;
        markings->done_in_current_line = NSMakeRange(cur_line_range.location, elem.range.location - cur_line_range.location + offset);
        markings->undone_in_current_line = NSMakeRange(elem.range.location + offset, cur_line_range.length - (elem.range.location - cur_line_range.location + offset));
    } else if (kind == LyricsKindSynced) {
        LSLyricsElement *elem = [lines objectAtIndex:line_idx];
        NSRange cur_line_range = elem.range;
        markings->current_line = cur_line_range;
        markings->finished_lines = NSMakeRange(0, cur_line_range.location);
        
        NSUInteger future_start = cur_line_range.location + cur_line_range.length;
        markings->future_lines = NSMakeRange(future_start, end_pos - future_start);
    }
}


@synthesize kind;
@synthesize lines;
@synthesize content;
@synthesize fileURL;

@end
