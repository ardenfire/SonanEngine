//
// CueSheetDecoder.m
//
// Copyright (c) 2012 ap4y (lod@pisem.net)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "CueSheetDecoder.h"
#import "CueSheet.h"

#import "AFSENPluginManager.h"

@interface CueSheetDecoder () {
	long framePosition;
	long trackStart;
	long trackEnd;		
}
@property (strong, nonatomic) id<AFSENSource> source;
@property (strong, nonatomic) id<AFSENDecoder> decoder;
@property (strong, nonatomic) CueSheet *cuesheet;
@end

@implementation CueSheetDecoder

- (void)dealloc {
    [self close];
}

#pragma mark - AFSENDecoder

+ (NSArray *)fileTypes  {
	return @[@"cue"];
}

- (NSDictionary *)properties {
	NSMutableDictionary *properties = [[_decoder properties] mutableCopy];
	properties[@"totalFrames"] = @(trackEnd - trackStart);
	return properties;
}

- (NSDictionary *)metadata {
    NSDictionary *resultDict = nil;
    for (CueSheetTrack *track in _cuesheet.tracks) {
        if ([(_source.url).fragment isEqualToString:track.track]) {
            resultDict = @{@"artist": track.artist,
                          @"album": track.album,
                          @"title": track.title,
                          @"track": @((track.track).intValue),
                          @"genre": track.genre,
                          @"year": track.year};
        }
    }
    return resultDict;
}

- (int)readAudio:(void *)buf frames:(UInt32)frames {
	if (framePosition + frames > trackEnd) {
		frames = (UInt32)(trackEnd - framePosition);
	}
    
	if (!frames) {
		return 0;
	}
    
	int n = [_decoder readAudio:buf frames:frames];
	framePosition += n;
	return n;
}

- (BOOL)open:(id<AFSENSource>)s {
	NSURL *url = [s url];
	self.cuesheet = [[CueSheet alloc] initWithURL:url];
	
    AFSENPluginManager *pluginManager = [AFSENPluginManager sharedManager];
	for (int i = 0; i < _cuesheet.tracks.count; i++) {
        CueSheetTrack *track = (_cuesheet.tracks)[i];
		if ([track.track isEqualToString:url.fragment]) {
			self.source = [pluginManager sourceForURL:track.url error:nil];

			if (![_source open:track.url]) {
				return NO;
			}

			self.decoder = [pluginManager decoderForSource:_source error:nil];
			if (![_decoder open:_source]) {
				return NO;
			}

			CueSheetTrack *nextTrack = nil;
			if (i + 1 < (_cuesheet.tracks).count) {
				nextTrack = (_cuesheet.tracks)[i + 1];
			}

			NSDictionary *properties = [_decoder properties];
			float sampleRate = [properties[@"sampleRate"] floatValue];
			trackStart = track.time * sampleRate;

			if (nextTrack && [nextTrack.url isEqual:track.url]) {
				trackEnd = nextTrack.time * sampleRate;
			} else {
				trackEnd = [properties[@"totalFrames"] doubleValue];
			}
			[self seek: 0];

			return YES;
		}
	}

	return NO;
}

- (long)seek:(long)frame {
	if (frame > trackEnd - trackStart) {
		return -1;
	}
	
	frame += trackStart;
	framePosition = [_decoder seek:frame];
	return framePosition;
}

- (void)close {
    [_decoder close];
    [_source close];
}

@end
