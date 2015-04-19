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
    time +=  0.1 * [[fmtr numberFromString:centiSec] intValue];
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

@end



@implementation LSLyrics
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
        [self loadLyrics];
    }
    return self;
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
    for (NSString *line in _lines) {
        LSLyricsElements *elems = [[LSLyricsElements alloc] initWithContent:ContentElements];
        NSArray *matches = [re matchesInString:line options:0 range:NSMakeRange(0, [line length])];
        for (NSTextCheckingResult *match in matches) {
            LSLyricsElement *elem = [LSLyricsElement elementWithString:line match:match];
            [elems addObject:elem];
        }
        [lines addObject:elems];
    }
}

- (void)parseSynced {
    NSError *err;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^\\[(\\d{2}):(\\d{2}):(\\d{2})\\](.*)$" options:0 error:&err];
    NSArray *_lines = [content componentsSeparatedByString:@"\n"];
    for (NSString *line in _lines) {
        NSTextCheckingResult *match = [re firstMatchInString:line options:0 range:NSMakeRange(0, [line length])];
        LSLyricsElement *elem = [LSLyricsElement elementWithString:line match:match];
        [lines addObject:elem];
    }
}

- (void)parseUnsynced {
    NSArray *_lines = [content componentsSeparatedByString:@"\n"];
    for (NSString *line in _lines) {
        [lines addObject:[[LSLyricsElement alloc] initWithString:line]];
    }
}

@synthesize kind;
@synthesize lines;
@synthesize content;
@synthesize fileURL;

@end
