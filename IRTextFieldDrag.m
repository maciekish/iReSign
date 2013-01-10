//
//  IRTextFieldDrag.m
//  iReSign
//
//  Created by Esteban Bouza on 01/12/12.
//

#import "IRTextFieldDrag.h"

@implementation IRTextFieldDrag

- (void)awakeFromNib {
    [self registerForDraggedTypes:@[NSFilenamesPboardType]];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if ( [[pboard types] containsObject:NSURLPboardType] ) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        if (files.count <= 0) {
            return NO;
        }
        self.stringValue = [files objectAtIndex:0];

    }
    return YES;
}


// Source: http://www.cocoabuilder.com/archive/cocoa/11014-dnd-for-nstextfields-drag-drop.html
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    
    if (!self.isEnabled) return NSDragOperationNone;
    
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
    
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
    
    if ( [[pboard types] containsObject:NSColorPboardType] ) {
        if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }
    
    return NSDragOperationNone;
}


@end
