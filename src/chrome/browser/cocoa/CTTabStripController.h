// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#ifndef CHROME_BROWSER_COCOA_TAB_STRIP_CONTROLLER_H_
#define CHROME_BROWSER_COCOA_TAB_STRIP_CONTROLLER_H_
#pragma once

#import <Cocoa/Cocoa.h>

#import "CTTabControllerTarget.h"

@class NewTabButton;
@class CTTabContentsController;
@class CTTabView;
@class CTTabStripView;

@class CTTabContents;
@class CTBrowser;

@interface CTTabStripController : NSObject<CTTabControllerTarget>

@property(nonatomic) CGFloat indentForControls;

@property(nonatomic, assign) BOOL showsNewTabButton;

- (id)initWithView:(CTTabStripView*)view switchView:(NSView*)switchView browser:(CTBrowser*)browser;

- (NSView*)selectedTabView;
- (void)setFrameOfSelectedTab:(NSRect)frame;
- (void)moveTabFromIndex:(NSInteger)from;

- (void)dropTabContents:(CTTabContents*)contents withFrame:(NSRect)frame asPinnedTab:(BOOL)pinned;

- (NSInteger)modelIndexForTabView:(NSView*)view;
- (NSView*)viewAtIndex:(NSUInteger)index;
- (NSUInteger)viewsCount;

- (void)insertPlaceholderForTab:(CTTabView*)tab frame:(NSRect)frame yStretchiness:(CGFloat)yStretchiness;

- (BOOL)isTabFullyVisible:(CTTabView*)tab;
- (void)layoutTabs;

- (BOOL)inRapidClosureMode;
- (BOOL)tabDraggingAllowed;

+ (CGFloat)defaultTabHeight;
+ (CGFloat)defaultIndentForControls;

- (CTTabContentsController*)activeTabContentsController;

@end

extern NSString* const kTabStripNumberOfTabsChanged;

#endif  // CHROME_BROWSER_COCOA_TAB_STRIP_CONTROLLER_H_
