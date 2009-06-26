//
//  LogController.m
//  GeektoolPreferencePane
//
//  Created by Kevin Nygaard on 3/18/09.
//  Copyright 2009 AllocInit. All rights reserved.
//

#import "LogController.h"
#import "GeekToolPrefs.h"
#import "GeekTool.h"
#import "GTLog.h"
#import "NSIndexSet+CountOfIndexesInRange.h"
#import "NSArrayController+Duplicate.h"

@implementation LogController

- (void)awakeFromNib
{
    MovedRowsType = @"GTLog_Moved_Item";
    CopiedRowsType = @"GTLog_Copied_Item";

    // register for drag and drop
    
	[tableView setDraggingSourceOperationMask:NSDragOperationLink forLocal:NO];
	[tableView setDraggingSourceOperationMask:(NSDragOperationCopy | NSDragOperationMove) forLocal:YES];
	
	[tableView registerForDraggedTypes:
    [NSArray arrayWithObjects:CopiedRowsType, MovedRowsType, nil]];
    [tableView setAllowsMultipleSelection:YES];
    
    [self addObserver:self forKeyPath:@"selectedObjects" options:0 context:nil];
    
    //oldSelectedLog = [[self selectedObjects]objectAtIndex:0];
}

- (id)sharedLogController
{
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // when a selection is changed
    if([keyPath isEqualToString:@"selectedObjects"])
    {
        // deselect old log if we can
        if (oldSelectedLog) [oldSelectedLog setHighlighted:NO];
        
        // if an object is selected update our old selected log and select it
        if ([[self selectedObjects]count])
        {
            oldSelectedLog = [[self selectedObjects]objectAtIndex:0];
            [oldSelectedLog setHighlighted:YES];
        }
    }    
}

// need to handle no selection
/*
- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes
{
    oldSelectionIndex = [self selectionIndex];
    newSelectionIndex = [proposedSelectionIndexes firstIndex];
    if (oldSelectionIndex != newSelectionIndex)
    {
        [[[self content] objectAtIndex:oldSelectionIndex]setHighlighted:NO];
        [[[self content] objectAtIndex:newSelectionIndex]setHighlighted:YES];
    }
    
    return proposedSelectionIndexes;
}
*/
#pragma mark Drag n' Drop Stuff
// thanks to mmalc for figuring most of this stuff out for me (and just being amazing)
- (BOOL)tableView:(NSTableView *)aTableView
writeRowsWithIndexes:(NSIndexSet *)rowIndexes
	 toPasteboard:(NSPasteboard *)pboard
{
	// declare our own pasteboard types
    NSArray *typesArray = [NSArray arrayWithObjects:MovedRowsType, nil];
		
    [pboard declareTypes:typesArray owner:self];
	
    // add rows array for local move
	NSData *rowIndexesArchive = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard setData:rowIndexesArchive forType:MovedRowsType];
	
	// create new array of selected rows for remote drop
    // could do deferred provision, but keep it direct for clarity
	NSMutableArray *rowCopies = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
	
    unsigned int currentIndex = [rowIndexes firstIndex];
    while (currentIndex != NSNotFound)
    {
		[rowCopies addObject:[[self arrangedObjects] objectAtIndex:currentIndex]];
        currentIndex = [rowIndexes indexGreaterThanIndex: currentIndex];
    }
	
	// setPropertyList works here because we're using dictionaries, strings,
	// and dates; otherwise, archive collection to NSData...
	[pboard setPropertyList:rowCopies forType:CopiedRowsType];
	
    return YES;
}


- (NSDragOperation)tableView:(NSTableView*)tv
				validateDrop:(id <NSDraggingInfo>)info
				 proposedRow:(int)row
	   proposedDropOperation:(NSTableViewDropOperation)op
{
    
    NSDragOperation dragOp = NSDragOperationCopy;
    
    // if drag source is self, it's a move unless the Option key is pressed
    if ([info draggingSource] == tableView) {
			dragOp =  NSDragOperationMove;
    }
    // we want to put the object at, not over,
    // the current row (contrast NSTableViewDropOn) 
    [tv setDropRow:row dropOperation:NSTableViewDropAbove];
	
    return dragOp;
}

- (BOOL)tableView:(NSTableView*)tv
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(int)row
	dropOperation:(NSTableViewDropOperation)op
{
    BOOL result = NO;
    
    if (row < 0) {
		row = 0;
	}
	// if drag source is self, it's a move unless the Option key is pressed
    if ([info draggingSource] == tableView)
    {
        //[[[self content] objectAtIndex:oldSelectionIndex]setHighlighted:NO];
        NSData *rowsData = [[info draggingPasteboard] dataForType:MovedRowsType];
        NSIndexSet *indexSet = [NSKeyedUnarchiver unarchiveObjectWithData:rowsData];
        
        NSIndexSet *destinationIndexes = [self moveObjectsInArrangedObjectsFromIndexes:indexSet toIndex:row];
        // set selected rows to those that were just moved
        [self setSelectionIndexes:destinationIndexes];
        
        result = YES;
    }
        
    return result;
}

-(NSIndexSet *) moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet*)fromIndexSet
												toIndex:(unsigned int)insertIndex
{	
	// If any of the removed objects come before the insertion index,
	// we need to decrement the index appropriately
	unsigned int adjustedInsertIndex =
	insertIndex - [fromIndexSet countOfIndexesInRange:(NSRange){0, insertIndex}];
	NSRange destinationRange = NSMakeRange(adjustedInsertIndex, [fromIndexSet count]);
	NSIndexSet *destinationIndexes = [NSIndexSet indexSetWithIndexesInRange:destinationRange];
	
	NSArray *objectsToMove = [[self arrangedObjects] objectsAtIndexes:fromIndexSet];
	[self removeObjectsAtArrangedObjectIndexes:fromIndexSet];	
	[self insertObjects:objectsToMove atArrangedObjectIndexes:destinationIndexes];
	
	return destinationIndexes;
}

@end
