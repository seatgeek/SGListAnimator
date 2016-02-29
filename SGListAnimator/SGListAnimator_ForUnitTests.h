//
//  SGListAnimator_ForUnitTests.h
//  SeatGeek
//
//  Created by David McNerney on 12/21/15.
//  Copyright © 2015 SeatGeek. All rights reserved.
//
// Here we expose some private classes and methods that SGListAnimator uses internally, so
// that we can test them.

#import "SGListAnimator.h"
@class SGListTransition;


@interface SGListAnimator ()

/**
 * Computes the operations necessary to go from the from section list to the to section list, and
 * returns one or more SGListTransition objects containing them. UITableView and UICollectionView place
 * some limits on the types of animation operations that can be grouped together in a single transition,
 * so ultiple transitions are returned in some situations to avoid placing incompatible operations in
 * the same transition.
 */
+ (NSArray<SGListTransition *> *)transitionObjectsFromSections:(NSArray<SGListSection *> *)oldSections
                                                    toSections:(NSArray<SGListSection *> *)newSections
                                                doSectionMoves:(BOOL)doSectionMoves
                                           doIntraSectionMoves:(BOOL)doIntraSectionMoves
                                           doInterSectionMoves:(BOOL)doInterSectionMoves;

@end
