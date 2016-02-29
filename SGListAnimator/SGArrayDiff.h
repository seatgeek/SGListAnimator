//
//  SGArrayDiff.h
//  SeatGeek
//
//  Created by David McNerney on 12/22/15.
//  Copyright © 2015 SeatGeek. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SGIndexTuple;

/**
 * Used by SGListTransition internally to compute & represent the set of operations
 * that are to be applied to take an array from one state to another.
 * All these arrays properties are arrays of array indices, for either
 * the old or the new state of the array, as indicated by the property name.
 */
@interface SGArrayDiff : NSObject

@property (nonatomic, copy) NSArray<NSNumber *> *deleteInOld;
@property (nonatomic, copy) NSArray<NSNumber *> *insertInNew;
@property (nonatomic, copy) NSArray<SGIndexTuple *> *moved;     /// Only provided if doMoves is set to YES
@property (nonatomic, copy) NSArray<SGIndexTuple *> *unchanged;

/**
 * Computes the operations necessary to go from the from array to the to array, and returns a
 * SGArrayDiff containing them, or nil if it wasn't able to compute a transition (happens
 * only for duplicates, or if reordering occurs when doMoves is passed false).
 * This is a general tool to find differences between arrays. It's used by SGListTransition to
 * find changes in what sections are present, and then, for sections that are present in old
 * and new both, changes in the contained items.
 */
+ (SGArrayDiff *)diffFromArray:(NSArray *)oldArray toArray:(NSArray *)newArray doMoves:(BOOL)doMoves includeUnchanged:(BOOL)includeUnchanged;

@end
