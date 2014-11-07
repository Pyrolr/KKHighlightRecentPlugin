//
//  KKFileUsageCounter.h
//  KKHighlightRecentPlugin
//
//  Created by Karol Kozub on 2014-11-07.
//  Copyright (c) 2014 Karol Kozub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KKNavigatorItemHighlighter.h"

@interface KKFileUsageCounter : NSObject <KKNavigatorItemHighlighterDataSource>

+ (instancetype)sharedInstance;
- (void)setup;
- (void)update;

@end
