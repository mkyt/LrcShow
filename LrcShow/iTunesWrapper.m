//
//  iTunesWrapper.m
//  LrcShow
//
//  Created by Masahiro Kiyota on 2016/07/16.
//  Copyright © 2016 Juzbox. All rights reserved.
//

#import "iTunesWrapper.h"

#import "iTunes.h"
#import "Music.h"


@implementation PlayerWrapper

+ (nullable instancetype)sharedInstance {
    if (@available(macOS 10.15, *)) {
        return [MusicWrapper sharedInstance];
    } else {
        return [iTunesWrapper sharedInstance];
    }
}

@end


@implementation iTunesWrapper

iTunesApplication *iTunes;


+ (nullable instancetype)sharedInstance {
    static iTunesWrapper* instance = nil;
    @synchronized (self) {
        if (!instance) {
            instance = [[self alloc] init];
        }
    }
    return instance;
}

- (nullable instancetype)init {
    if (self = [super init]) {
        iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    }
    return self;
}

- (PlayerState)state {
    iTunesEPlS playerState = [iTunes playerState];
    if (playerState == iTunesEPlSStopped) {
        return PlayerStateStopped;
    } else if (playerState == iTunesEPlSPlaying) {
        return PlayerStatePlaying;
    } else {
        return PlayerStatePause;
    }
}

- (NSInteger)databaseID {
    return [[iTunes currentTrack] databaseID];
}

- (double)playerPosition {
    return [iTunes playerPosition];
}

- (nullable NSURL*)location {
    iTunesFileTrack *track = (iTunesFileTrack *)[[iTunes currentTrack] get];  // [iTunes currentTrack] returns iTunesTrack, not iTunesFileTrack, hence cannot get file path
    return [track location];
}

- (nullable NSString*)trackDescription {
    iTunesFileTrack *track = (iTunesFileTrack *)[[iTunes currentTrack] get];  // [iTunes currentTrack] returns iTunesTrack, not iTunesFileTrack, hence cannot get file path
    NSString *title = [track name];
    NSString *album = [track album];
    NSString *artist = [track artist];
    return [NSString stringWithFormat:@"%@ - %@ - %@", title, artist, album];
}

@end


@implementation MusicWrapper

MusicApplication *musicApp;


+ (nullable instancetype)sharedInstance {
    static MusicWrapper* instance = nil;
    @synchronized (self) {
        if (!instance) {
            instance = [[self alloc] init];
        }
    }
    return instance;
}

- (nullable instancetype)init {
    if (self = [super init]) {
        musicApp = [SBApplication applicationWithBundleIdentifier:@"com.apple.Music"];
    }
    return self;
}

- (PlayerState)state {
    MusicEPlS playerState = [musicApp playerState];
    if (playerState == iTunesEPlSStopped) {
        return PlayerStateStopped;
    } else if (playerState == iTunesEPlSPlaying) {
        return PlayerStatePlaying;
    } else {
        return PlayerStatePause;
    }
}

- (NSInteger)databaseID {
    return [[musicApp currentTrack] databaseID];
}

- (double)playerPosition {
    return [musicApp playerPosition];
}

- (nullable NSURL*)location {
    MusicFileTrack *track = (MusicFileTrack *)[[musicApp currentTrack] get];  // [musicApp currentTrack] returns MusicTrack, not MusicFileTrack, hence cannot get file path
    return [track location];
}

- (nullable NSString*)trackDescription {
    MusicFileTrack *track = (MusicFileTrack *)[[musicApp currentTrack] get];  // [musicApp currentTrack] returns MusicTrack, not MusicFileTrack, hence cannot get file path
    NSString *title = [track name];
    NSString *album = [track album];
    NSString *artist = [track artist];
    return [NSString stringWithFormat:@"%@ - %@ - %@", title, artist, album];
}

@end
