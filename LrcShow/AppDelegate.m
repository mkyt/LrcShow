//
//  AppDelegate.m
//  LrcShow
//
//  Created by Hiro on 4/19/15.
//  Copyright (c) 2015 Juzbox. All rights reserved.
//

#import "AppDelegate.h"
#import "iTunes.h"
#import "LSLyrics.h"

#define TIMER_INTERVAL_POLLING  1.
#define TIMER_INTERVAL_PLAYBACK 0.2

typedef NS_ENUM(NSUInteger, AppState) {
    StatePolling,
    StatePlaying
};

@interface AppDelegate ()
{
    iTunesApplication *iTunes;
    AppState state;
    NSTimer *timer;
    NSInteger databaseID; // databaseID of the current track
    LSLyrics *lyrics;
    double duration; // duration of the current track
}

@property (weak) IBOutlet NSPanel *window;
@property (unsafe_unretained) IBOutlet NSTextView *lyricsTextView;

@end

@implementation AppDelegate

- (NSString *)trackDescription:(iTunesFileTrack *)track {
    NSString *title = [track name];
    NSString *album = [track album];
    NSString *artist = [track artist];
    // FIXME
    return [NSString stringWithFormat:@"%@ - %@ - %@", title, artist, album];
}

- (void)trackChanged {
    iTunesFileTrack *currentTrack = [[iTunes currentTrack] get]; // [iTunes currentTrack] returns iTunesTrack, not iTunesFileTrack, hence cannot get file path
    if (!currentTrack) {
        window.title = @"Stopped";
        lyricsTextView.string = @"";
        return;
    }
    iTunesFileTrack *track = (iTunesFileTrack *)[[iTunes currentTrack] get];
    window.title = [self trackDescription:track];
    databaseID = [track databaseID];
    NSURL *url = [track location];
    lyrics = [LSLyrics lyricsWithMusicFileURL:url];
    if (lyrics) {
        lyricsTextView.string = [[lyrics lines] joinedElement];
    } else {
        lyricsTextView.string = @"";
    }
}

- (void)polling:(NSTimer *)t {
    iTunesEPlS playerState = [iTunes playerState];
    if (playerState != iTunesEPlSStopped) {
        [timer invalidate];
        timer = nil;
        [self trackChanged];
        [self transitToState:StatePlaying];
    }
}

- (void)playing:(NSTimer *)t {
    iTunesEPlS playerState = [iTunes playerState];
    static lyrics_pos_t pos;
    if (playerState == iTunesEPlSStopped) {
        [timer invalidate];
        timer = nil;
        window.title = @"Stopped";
        lyricsTextView.string = @"";
        [self transitToState:StatePolling];
    } else {
        NSInteger dbID = [[iTunes currentTrack] databaseID];
        if (dbID != databaseID) { // track changed
            [self trackChanged];
            return;
        }
        if (lyrics != nil && [lyrics kind] != LyricsKindUnsynced) { // need to update markings
            double t = [iTunes playerPosition];
            BOOL updated = [lyrics positionForTime:t pos:&pos];
            if (updated) {
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
    iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    [self transitToState:StatePolling];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@synthesize window;
@synthesize lyricsTextView;

@end
