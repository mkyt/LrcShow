//
//  LSLyrics.h
//  LrcShow
//
//  Created by Hiro on 4/19/15.
//  Copyright (c) 2015 Juzbox. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, LyricsKind) {
    LyricsKindKaraoke,
    LyricsKindSynced,
    LyricsKindUnsynced
};

@protocol LSLyricsChunk <NSObject>

@property NSRange range;

@end

@interface LSLyricsElement : NSString <LSLyricsChunk>

+ (LSLyricsElement *)elementWithString:(NSString *)string timeCode:(double)time;
+ (LSLyricsElement *)elementWithString:(NSString *)string match:(NSTextCheckingResult *)match;

- (instancetype)initWithString:(NSString *)string timeCode:(double)time;
- (instancetype)initWithString:(NSString *)aString;

@property (readonly) double timeCode; // in seconds

@end

typedef NS_ENUM(NSUInteger, LyricsElementsContent) {
    ContentLines,
    ContentElements
};

@interface LSLyricsElements : NSMutableArray <LSLyricsChunk>

- initWithContent:(LyricsElementsContent)content;
- (LSLyricsElement *)joinedElement;

@property (readonly) LyricsElementsContent content;

@end

typedef struct lyrics_pos_s {
    NSInteger line;
    NSInteger elem_index;
    NSInteger char_index_in_elem;
} lyrics_pos_t;

typedef struct lyrics_marking_s {
    NSRange finished_lines;
    NSRange current_line;
    NSRange done_in_current_line;
    NSRange undone_in_current_line;
    NSRange future_lines;
} lyrics_marking_t;

@interface LSLyrics : NSObject

+ (LSLyrics *)lyricsWithMusicFileURL:(NSURL *)musicFileURL;
+ (LSLyrics *)lyricsWithLyricsFileURL:(NSURL *)fileURL;
- (instancetype)initWithLyricsFileURL:(NSURL *)fileURL;
- (BOOL)positionForTime:(double)time pos:(lyrics_pos_t *)pos;
- (void)markingsForPos:(const lyrics_pos_t *)pos markings:(lyrics_marking_t *)markings;

@property (readonly) LyricsKind kind;
@property (readonly) LSLyricsElements *lines;
@property (readonly) NSString* content;
@property (readonly) NSURL *fileURL;

@end
