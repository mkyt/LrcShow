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

@interface LSLyricsElement : NSString

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

@interface LSLyricsElements : NSMutableArray

- initWithContent:(LyricsElementsContent)content;
- (LSLyricsElement *)joinedElement;

@property (readonly) LyricsElementsContent content;

@end

@interface LSLyrics : NSObject

+ (LSLyrics *)lyricsWithMusicFileURL:(NSURL *)musicFileURL;
+ (LSLyrics *)lyricsWithLyricsFileURL:(NSURL *)fileURL;
- (instancetype)initWithLyricsFileURL:(NSURL *)fileURL;

@property (readonly) LyricsKind kind;
@property (readonly) LSLyricsElements *lines;
@property (readonly) NSString* content;
@property (readonly) NSURL *fileURL;

@end
