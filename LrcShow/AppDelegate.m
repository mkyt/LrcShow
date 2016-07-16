//
//  AppDelegate.m
//  LrcShow
//
//  Created by Hiro on 4/19/15.
//  Copyright (c) 2015 Juzbox. All rights reserved.
//

#import "AppDelegate.h"
#import "LSLyrics.h"
#import "iTunesWrapper.h"

#define TIMER_INTERVAL_POLLING  1.
#define TIMER_INTERVAL_PLAYBACK 0.1

typedef NS_ENUM(NSUInteger, AppState) {
    StatePolling,
    StatePlaying
};

@interface AppDelegate ()
{
    iTunesWrapper *iTunes;
    AppState state;
    NSTimer *timer;
    NSInteger databaseID; // databaseID of the current track
    LSLyrics *lyrics;
    double duration; // duration of the current track
    double prevPlayTime;
    NSDate *prevPlayTimeDate;
}

@property (weak) IBOutlet NSPanel *window;
@property (unsafe_unretained) IBOutlet NSTextView *lyricsTextView;
@property (weak) IBOutlet NSScrollView *scrollView;

@end

@implementation AppDelegate

- (void)trackChanged {
    window.title = [iTunes trackDescription];
    databaseID = [iTunes databaseID];
    NSURL *url = [iTunes location];
    lyrics = [LSLyrics lyricsWithMusicFileURL:url];
    if (lyrics) {
        lyricsTextView.string = [[lyrics lines] joinedElement];
        lyricsTextView.textColor = [NSColor whiteColor];
    } else {
        lyricsTextView.string = @"";
    }
    prevPlayTime = -1;
    prevPlayTimeDate = nil;
}

- (void)polling:(NSTimer *)t {
    if ([iTunes state] == PlayerStatePlaying) {
        [timer invalidate];
        timer = nil;
        [self trackChanged];
        [self transitToState:StatePlaying];
    }
}

- (void)scrollToLine:(NSInteger)line {
    NSClipView* clipView = [scrollView contentView];
    CGFloat clipHeight = scrollView.frame.size.height;
    CGFloat textHeight = clipView.documentRect.size.height;
    // NSLog(@"clip: %f, text: %f", clipHeight, textHeight);
    if (clipHeight >= textHeight) return; // whole text is displayed
    NSUInteger lines = lyrics.lines.count;
    CGFloat lineHeight = textHeight / lines;
    NSUInteger l = (NSUInteger)(clipHeight / lineHeight / 2);
    CGFloat to;
    if (line < l) to = 0.0;
    else if (line + l >= lines) to = textHeight - clipHeight;
    else to = lineHeight * (0.5 + line) - clipHeight / 2;
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.5];
    NSPoint ori = [clipView bounds].origin;
    ori.y = to;
    [[clipView animator] setBoundsOrigin:ori];
    [NSAnimationContext endGrouping];
}

- (void)playing:(NSTimer *)t {
    static lyrics_pos_t pos;
    PlayerState playerState = [iTunes state];
    if (playerState == PlayerStateStopped) {
        [timer invalidate];
        timer = nil;
        window.title = @"Stopped";
        lyricsTextView.string = @"";
        [self transitToState:StatePolling];
    } else {
        NSInteger dbID = [iTunes databaseID];
        if (dbID != databaseID) { // track changed
            [self trackChanged];
            pos.line = -2;
            return;
        }
        if (lyrics != nil && [lyrics kind] != LyricsKindUnsynced) { // need to update markings
            double t = [iTunes playerPosition];
            // playerPosition is updated only about once per second
            if (playerState == PlayerStatePlaying && t == prevPlayTime) { // not updated
                double diff = [prevPlayTimeDate timeIntervalSinceNow];
                t -= diff;
            } else { // updated
                prevPlayTime = t;
                prevPlayTimeDate = [NSDate date];
            }
            BOOL updated = [lyrics positionForTime:t pos:&pos];
            if (updated) {
                [self scrollToLine:pos.line];
                lyrics_marking_t markings;
                [lyrics markingsForPos:&pos markings:&markings];
                [lyricsTextView.textStorage addAttribute:NSForegroundColorAttributeName value:[NSColor grayColor] range:markings.finished_lines];
                [lyricsTextView.textStorage addAttribute:NSForegroundColorAttributeName value:[NSColor orangeColor] range:markings.current_line];
                [lyricsTextView.textStorage addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:markings.future_lines];
                if ([lyrics kind] == LyricsKindKaraoke) {
                    [lyricsTextView.textStorage addAttribute:NSForegroundColorAttributeName value:[NSColor grayColor] range:markings.done_in_current_line];
                }
            }
        }
    }
}

- (void)transitToState:(AppState)newState {
    if (timer) {
        [timer invalidate];
    }
    state = newState;
    double interval;
    SEL sel;
    switch (state) {
        case StatePolling:
            interval = TIMER_INTERVAL_POLLING;
            sel = @selector(polling:);
            break;
        case StatePlaying:
            interval = TIMER_INTERVAL_PLAYBACK;
            sel = @selector(playing:);
            break;
    }
    timer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:sel userInfo:nil repeats:YES];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    iTunes = [iTunesWrapper sharedInstance];
    [self transitToState:StatePolling];
    [window setLevel:NSNormalWindowLevel];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@synthesize window;
@synthesize lyricsTextView;
@synthesize scrollView;

@end
