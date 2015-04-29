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

#define TIMER_INTERVAL_POOLING  1.
#define TIMER_INTERVAL_PLAYBACK 0.2

typedef NS_ENUM(NSUInteger, AppState) {
    StatePooling,
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
@property (weak) IBOutlet NSTextField *trackInfoTextField;
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
        trackInfoTextField.stringValue = @"Stopped";
        lyricsTextView.string = @"";
        return;
    }
    iTunesFileTrack *track = (iTunesFileTrack *)[[iTunes currentTrack] get];
    trackInfoTextField.stringValue = [self trackDescription:track];
    databaseID = [track databaseID];
    NSURL *url = [track location];
    lyrics = [LSLyrics lyricsWithMusicFileURL:url];
    if (lyrics) {
        lyricsTextView.string = [[lyrics lines] joinedElement];
    } else {
        lyricsTextView.string = @"";
    }
}

- (void)pooling:(NSTimer *)t {
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
        trackInfoTextField.stringValue = @"Stopped";
        lyricsTextView.string = @"";
        [self transitToState:StatePooling];
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
        case StatePooling:
            interval = TIMER_INTERVAL_POOLING;
            sel = @selector(pooling:);
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
    [self transitToState:StatePooling];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@synthesize trackInfoTextField;
@synthesize lyricsTextView;

@end
