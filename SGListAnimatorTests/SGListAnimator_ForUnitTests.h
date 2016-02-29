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

+ (NSArray<SGListTransition *> *)transitionObjectsFromSections:(NSArray<SGListSection *> *)oldSections
                                                    toSections:(NSArray<SGListSection *> *)newSections
                                                doSectionMoves:(BOOL)doSectionMoves
                                           doIntraSectionMoves:(BOOL)doIntraSectionMoves
                                           doInterSectionMoves:(BOOL)doInterSectionMoves;

@end
