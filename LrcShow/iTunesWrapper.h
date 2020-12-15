//
//  iTunesWrapper.h
//  LrcShow
//
//  Created by Masahiro Kiyota on 2016/07/16.
//  Copyright © 2016 Juzbox. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PlayerState) {
    PlayerStateStopped,
    PlayerStatePlaying,
    PlayerStatePause
};

@interface PlayerWrapper : NSObject

+ (nullable instancetype)sharedInstance;

- (nullable instancetype)init;
- (PlayerState)state;
- (NSInteger)databaseID;
- (double)playerPosition;
- (nullable NSURL*)location;
- (nullable NSString*)trackDescription;

@end

@interface iTunesWrapper : PlayerWrapper
@end

@interface MusicWrapper : PlayerWrapper
@end
