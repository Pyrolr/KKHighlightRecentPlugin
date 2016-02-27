//
//  KKFileUsageCounter.m
//  KKHighlightRecentPlugin
//
//  Created by Karol Kozub on 2014-11-07.
//  Copyright (c) 2014 Karol Kozub. All rights reserved.
//

#import "KKFileUsageCounter.h"
#import "KKXcodeRuntime.h"
#import "NSObject+KKSwizzleMethods.h"


@interface KKFileUsageCounter ()

@property (nonatomic, strong) NSMutableDictionary *highlightsForFileUrls;
@property (nonatomic, strong) NSURL *focusedFileUrl;
@property (nonatomic, assign) double focusedFileHighlightIncrement;
@property (nonatomic, assign) double highlightDecayFactor;
@property (nonatomic, assign) double highlightPrecision;
@property (nonatomic, assign) NSTimeInterval updateInterval;

@end


@implementation KKFileUsageCounter

+ (instancetype)sharedInstance
{
    static KKFileUsageCounter *sharedInstance;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [self new];
    });
    
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        self.highlightsForFileUrls = [NSMutableDictionary dictionary];
        self.focusedFileUrl = nil;
        self.focusedFileHighlightIncrement = 0.0002;
        self.highlightDecayFactor = 0.9999;
        self.highlightPrecision = 0.05;
        self.updateInterval = 0.1;
    }
    
    return self;
}

- (void)start
{
    [NSTimer scheduledTimerWithTimeInterval:self.updateInterval target:self selector:@selector(update) userInfo:nil repeats:YES];
}

- (void)update
{
    for (NSURL *fileUrl in [self.highlightsForFileUrls.keyEnumerator allObjects]) {
        double highlight = [self.highlightsForFileUrls[fileUrl] doubleValue];
        double increment = [fileUrl isEqual:self.focusedFileUrl] ? self.focusedFileHighlightIncrement : 0;
        double updatedHighlight = (highlight + increment) * self.highlightDecayFactor;
        
        if ([self roundedHighlightForHighlight:updatedHighlight] < self.highlightPrecision) {
            [self.highlightsForFileUrls removeObjectForKey:fileUrl];
            
        } else {
            [self.highlightsForFileUrls setObject:@(updatedHighlight) forKey:fileUrl];
        }
        
        if ([self isHighlightChangeSignificantForHighlight:highlight updatedHighlight:updatedHighlight]) {
            [self.delegate fileUsageCounter:self didUpdateHighlightForFileUrl:fileUrl];
        }
    }
}

- (BOOL)isHighlightChangeSignificantForHighlight:(double)highlight updatedHighlight:(double)updatedHighlight
{
    return [self roundedHighlightForHighlight:highlight] != [self roundedHighlightForHighlight:updatedHighlight];
}

- (double)roundedHighlightForHighlight:(double)highlight
{
    return MAX(0, MIN(1, floor(highlight / self.highlightPrecision) * self.highlightPrecision));
}

#pragma mark - API for IDEEditorContext

- (void)editorContext:(IDEEditorContext *)editorContext didOpenItem:(id)item
{
    if ([item respondsToSelector:@selector(fileURL)]) {
        self.focusedFileUrl = [item fileURL];
        
        if (self.focusedFileUrl) {
            //            NSLog(@"Current File %@",self.focusedFileUrl);
            NSString *userDesktopPath = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES)[0];
            
            NSString *strLogPath = [userDesktopPath stringByAppendingPathComponent:@"RecentFiles.txt"];
            
            NSError *error = nil;
            
            NSString *strFileName = [NSString stringWithFormat:@"## %@ ##\r\n",self.focusedFileUrl.lastPathComponent];
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if(![fileManager fileExistsAtPath:strLogPath])
            {
                [strFileName writeToFile:strLogPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
            }
            else
            {
                NSFileHandle *myHandle = [NSFileHandle fileHandleForWritingAtPath:strLogPath];
                [myHandle seekToEndOfFile];
                [myHandle writeData:[strFileName dataUsingEncoding:NSUTF8StringEncoding]];
            }
            
            //            NSString *strFile = [NSString stringWithContentsOfURL:self.focusedFileUrl encoding:NSUTF8StringEncoding error:nil];
            // NSLog(@"Current File %@",strFile);
            NSFileHandle *myHandle = [NSFileHandle fileHandleForWritingAtPath:strLogPath];
            [myHandle seekToEndOfFile];
            [myHandle writeData:[self.focusedFileUrl.lastPathComponent dataUsingEncoding:NSUTF8StringEncoding]];
            
            if (error) {
                NSLog(@"Error %@",error.localizedDescription);
            }
            
            //            NSArray* temp = [NSArray arrayWithContentsOfFile:strLogPath];
            //            if (temp) {
            //                NSMutableSet* setFiles = [NSMutableSet setWithArray:temp];
            //                [setFiles addObject:self.focusedFileUrl];
            //                NSArray* temp = setFiles.allObjects;
            //
            //                if (temp) {
            //                    [temp writeToFile:strLogPath atomically:YES];
            //                }
            //            } else {
            //                NSSet *setFiles = [NSSet setWithObject:self.focusedFileUrl];
            //                NSArray* temp = setFiles.allObjects;
            //
            //                if (temp) {
            //                    [temp writeToFile:strLogPath atomically:YES];
            //                }
            //
            //            }
        }
        
        if (self.focusedFileUrl && ![self.highlightsForFileUrls objectForKey:self.focusedFileUrl]) {
            [self.highlightsForFileUrls setObject:@(self.highlightPrecision) forKey:self.focusedFileUrl];
        }
    }
}

#pragma mark - KKNavigatorItemHighlighterDataSource

- (double)navigatorItemHighlighter:(KKNavigatorItemHighlighter *)navigatorItemHighlighter highlightForFileUrl:(NSURL *)fileUrl
{
    double highlight = [self.highlightsForFileUrls[fileUrl] doubleValue];
    
    return [self roundedHighlightForHighlight:highlight];
}

@end


@implementation IDEEditorContext (KKHighlightRecentPlugin)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [IDEEditorContext kk_swizzleMethodWithOriginalSelector:@selector(_openNavigableItem:documentExtension:document:shouldInstallEditorBlock:)];
    });
}

- (int)kk__openNavigableItem:(id)item documentExtension:(id)documentExtension document:(id)document shouldInstallEditorBlock:(id)block
{
    [[KKFileUsageCounter sharedInstance] editorContext:self didOpenItem:item];
    
    return [self kk__openNavigableItem:item documentExtension:documentExtension document:document shouldInstallEditorBlock:block];
}

@end
