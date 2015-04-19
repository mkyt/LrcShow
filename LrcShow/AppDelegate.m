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
#define TIMER_INTERVAL_PLAYBACK 0.01

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
@property (weak) IBOutlet NSTextField *lyricsTextField;

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
        lyricsTextField.stringValue = @"";
        return;
    }
    iTunesFileTrack *track = (iTunesFileTrack *)[[iTunes currentTrack] get];
    trackInfoTextField.stringValue = [self trackDescription:track];
    NSURL *url = [track location];
    lyrics = [LSLyrics lyricsWithMusicFileURL:url];
    if (lyrics) {
        lyricsTextField.stringValue = [[lyrics lines] joinedElement];
    } else {
        lyricsTextField.stringValue = @"";
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
    if (playerState == iTunesEPlSStopped) {
        [timer invalidate];
        timer = nil;
        trackInfoTextField.stringValue = @"Stopped";
        lyricsTextField.stringValue = @"";
        [self transitToState:StatePooling];
    } else {
        NSInteger dbID = [[iTunes currentTrack] databaseID];
        if (dbID != databaseID) { // track changed
            [self trackChanged];
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
@synthesize lyricsTextField;

@end
