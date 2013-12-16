//
//  IRHelpWindow.m
//  iReSign
//
//  Created by Shmoopi on 12/13/13.
//  Copyright (c) 2013 nil. All rights reserved.
//

#import "IRHelpWindow.h"

@implementation IRHelpWindow

// Move the window by dragging
- (BOOL)isMovableByWindowBackground {
    return YES;
}

// Close the window
- (IBAction)closeOK:(id)sender {
    [self close];
}

@end
