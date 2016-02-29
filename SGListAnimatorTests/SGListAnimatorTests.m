//
//  SGListAnimatorTests.m
//  SeatGeek
//
//  Created by David McNerney on 12/21/15.
//  Copyright © 2015 SeatGeek. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SGListAnimator_ForUnitTests.h"
#import "SGListSection.h"
#import "SGListTransition.h"
#import "SGArrayDiff.h"
#import "SGIndexTuple.h"


/**
 * On the string shorthand used here, in the demo app, and probably in any diagnostic console
 * logging:
 *
 * Below we represent lists by strings like "A.ab,B.c", where sections are separated by commas,
 * the section title string is separated from the items by a period, and the items in each section
 * are represented by one character each. So in the example, "A" and "B" are section title
 * strings, while "a", "b", and "c" are the item objects. All this is parsed by our helper method
 * below, -sectionsForString:.
 *
 * We represent SGListTransitions using strings like "S+1;I+0.1". Types of operations are
 * separated by semicolons, individual indices, pairs of indices, index paths, or pairs of index
 * paths are comma separated. Indices are numbers, index paths separate section and item with a
 * period, and pairs of things are separated with a forward slash. The types of operations go in a
 * particular order and are represented by "S*", "S-", "I-", etc. This format is output by
 * SGListTransition -description, so see the code over there.
 *
 * We represent SGArrayDiffs using simpler but analogous strings like ">0/1,1/0;-2,3,4". Again,
 * types of operations separated by semicolons, individual indices by commas, pairs of indices by
 * a forward slash. Operations are "=" (only if includeUnchanged is true), ">" for moves,
 * "-" for deletes, "+" for inserts. See SGArrayDiff -description.
 *
 * We have specific rules about what world all these indices and index paths are in for each type
 * of operation, mirroring how UITableView and UICollectionView work, and keeping things sane.
 * This is clear from the names of the SGListTransition and SGArrayDiff properties, but here's
 * a summary:
 *      reload section / array element unchanged: index is in old list/array
 *      delete anything: old
 *      insert anything: new
 *      move anything: old/new
 */

@interface SGListAnimatorTests : XCTestCase
@end


@implementation SGListAnimatorTests

#pragma mark - SGListAnimator private methods

- (void)testTransitionObjectsFromSectionsToSectionsDoMoves {
    {
        // Transition with moves enabled but no moves possible
        NSArray<SGListSection *> *oldSections = [self sectionsForString:@"A.a"];
        NSArray<SGListSection *> *newSections = [self sectionsForString:@"A.ab,B.c"];
        NSArray<SGListTransition *> *transitions = [SGListAnimator transitionObjectsFromSections:oldSections toSections:newSections doSectionMoves:YES doIntraSectionMoves:YES doInterSectionMoves:YES];
        XCTAssertEqual(transitions.count, 1);
        XCTAssertEqualObjects(transitions.firstObject.description, @"S+1;I+0.1");
    }

    {
        // Transition with moves enabled and possible, insert new section
        NSArray<SGListSection *> *oldSections = [self sectionsForString:@"A.abcd"];
        NSArray<SGListSection *> *newSections = [self sectionsForString:@"A.ac,B.bd"];
        NSArray<SGListTransition *> *transitions = [SGListAnimator transitionObjectsFromSections:oldSections toSections:newSections doSectionMoves:YES doIntraSectionMoves:YES doInterSectionMoves:YES];
        XCTAssertEqual(transitions.count, 2);
        XCTAssertEqualObjects(transitions[0].description, @"S+1");
        XCTAssertEqualObjects(transitions[1].description, @"I>0.1/1.0,0.3/1.1");

        // Transition with moves disabled and possible
        NSArray<SGListTransition *> *transitionsNoMoves = [SGListAnimator transitionObjectsFromSections:oldSections toSections:newSections doSectionMoves:NO doIntraSectionMoves:NO doInterSectionMoves:NO];
        XCTAssertEqual(transitionsNoMoves.count, 1);
        XCTAssertEqualObjects(transitionsNoMoves[0].description, @"I-0.1,0.3;S+1");
    }

    {
        // Transition with moves enabled and possible, delete old section and insert new section with different ordering
        NSArray<SGListSection *> *oldSections = [self sectionsForString:@"A.abcd"];
        // middle state 1:                                              @"B.,A.abcd"
        // middle state 2:                                              @"B.dcba,A."
        NSArray<SGListSection *> *newSections = [self sectionsForString:@"B.dcba"];
        NSArray<SGListTransition *> *transitions = [SGListAnimator transitionObjectsFromSections:oldSections toSections:newSections doSectionMoves:YES doIntraSectionMoves:YES doInterSectionMoves:YES];
        XCTAssertEqual(transitions.count, 3);
        XCTAssertEqualObjects(transitions[0].description, @"S+0");
        XCTAssertEqualObjects(transitions[1].description, @"I>1.0/0.3,1.1/0.2,1.2/0.1,1.3/0.0");
        XCTAssertEqualObjects(transitions[2].description, @"S-1");
    }

    {
        // Transition with moves enabled and possible, move section and change ordering of items within
        NSArray<SGListSection *> *oldSections = [self sectionsForString:@"A.abc,B.def,C.ghi"];
        // middle state:                                                @"A.abc,C.ghi,B.def"
        NSArray<SGListSection *> *newSections = [self sectionsForString:@"A.abc,C.ghi,B.edf"];
        NSArray<SGListTransition *> *transitions = [SGListAnimator transitionObjectsFromSections:oldSections toSections:newSections doSectionMoves:YES doIntraSectionMoves:YES doInterSectionMoves:YES];
        XCTAssertEqual(transitions.count, 2);
        XCTAssertEqualObjects(transitions[0].description, @"S>1/2,2/1");
        XCTAssertEqualObjects(transitions[1].description, @"I<2.0/2.1,2.1/2.0");
    }

    {
        // Transition with moves disabled but section move present
        NSArray<SGListSection *> *oldSections = [self sectionsForString:@"A.a,B.b"];
        NSArray<SGListSection *> *newSections = [self sectionsForString:@"B.b,A.a"];
        NSArray<SGListTransition *> *transitions = [SGListAnimator transitionObjectsFromSections:oldSections toSections:newSections doSectionMoves:NO doIntraSectionMoves:NO doInterSectionMoves:NO];
        XCTAssertEqual(transitions.count, 1);
        XCTAssertEqualObjects(transitions[0].description, @"*");
    }

    {
        // Transition with moves enabled, move section and move item from that section to another
        NSArray<SGListSection *> *oldSections = [self sectionsForString:@"A.abc,B.def"];
        // middle state:                                                @"B.def,A.abc"
        NSArray<SGListSection *> *newSections = [self sectionsForString:@"B.de,A.abcf"];
        NSArray<SGListTransition *> *transitions = [SGListAnimator transitionObjectsFromSections:oldSections toSections:newSections doSectionMoves:YES doIntraSectionMoves:YES doInterSectionMoves:YES];
        XCTAssertEqual(transitions.count, 2);
        XCTAssertEqualObjects(transitions[0].description, @"S>0/1,1/0");
        XCTAssertEqualObjects(transitions[1].description, @"I>0.2/1.3");
    }

    {
        // Transition with moves enabled, move section and also insert/delete some sections
        NSArray<SGListSection *> *oldSections = [self sectionsForString:@"A.abc,B.def,C.ghi,D.jkl"];
        // middle state 1:                                              @"A.abc,B.def,C.ghi,D.jkl,E."            // after insert section
        // middle state 2:                                              @"A.abc,D.jkl,C.ghi,B.def,E."            // after section move
        // middle state 3:                                              @"A.abcz,D.jkl,C.,B.def,E.mno"           // after all other operations
        NSArray<SGListSection *> *newSections = [self sectionsForString:@"A.abcz,D.jkl,B.def,E.mno"];            // after delete section
        NSArray<SGListTransition *> *transitions = [SGListAnimator transitionObjectsFromSections:oldSections toSections:newSections doSectionMoves:YES doIntraSectionMoves:YES doInterSectionMoves:YES];

        XCTAssertEqual(transitions.count, 4);

        XCTAssertEqualObjects(transitions[0].description, @"S+4");
        XCTAssertEqualObjects(transitions[1].description, @"S>1/3,3/1");
        XCTAssertEqualObjects(transitions[2].description, @"I-2.0,2.1,2.2;I+0.3,4.0,4.1,4.2");
        XCTAssertEqualObjects(transitions[3].description, @"S-2");

        XCTAssertEqualObjects([self stringForSections:transitions[0].fromSections], @"A.abc,B.def,C.ghi,D.jkl");
        XCTAssertEqualObjects([self stringForSections:transitions[0].toSections],   @"A.abc,B.def,C.ghi,D.jkl,E.");
        XCTAssertEqualObjects([self stringForSections:transitions[1].fromSections], @"A.abc,B.def,C.ghi,D.jkl,E.");
        XCTAssertEqualObjects([self stringForSections:transitions[1].toSections],   @"A.abc,D.jkl,C.ghi,B.def,E.");
        XCTAssertEqualObjects([self stringForSections:transitions[2].fromSections], @"A.abc,D.jkl,C.ghi,B.def,E.");
        XCTAssertEqualObjects([self stringForSections:transitions[2].toSections],   @"A.abcz,D.jkl,C.,B.def,E.mno");
        XCTAssertEqualObjects([self stringForSections:transitions[3].fromSections], @"A.abcz,D.jkl,C.,B.def,E.mno");
        XCTAssertEqualObjects([self stringForSections:transitions[3].toSections],   @"A.abcz,D.jkl,B.def,E.mno");

    }
}

#pragma mark - SGListTransition public methods

- (void)testComputeOperations {
    // No moves
    [self assertTransitionFrom:@""                           to:@"A.a"                      sm:NO  iasm:NO  is:@"S+0"];                  // insert first section
    [self assertTransitionFrom:@"A.a"                        to:@""                         sm:NO  iasm:NO  is:@"S-0"];                  // delete last section
    [self assertTransitionFrom:@""                           to:@"A.a,B.a"                  sm:NO  iasm:NO  is:@"S+0,1"];                // insert first two sections
    [self assertTransitionFrom:@"A.a,B.abc"                  to:@""                         sm:NO  iasm:NO  is:@"S-0,1"];                // delete last two sections
    [self assertTransitionFrom:@"A.a"                        to:@"A.a"                      sm:NO  iasm:NO  is:@""];                     // one section unchanged
    [self assertTransitionFrom:@"A.abcdef,B.fgkjlds"         to:@"A.abcdef,B.fgkjlds"       sm:NO  iasm:NO  is:@""];                     // two bigger sections unchanged
    [self assertTransitionFrom:@"A.abcdef,B.nopqrstuvwxyz"   to:@"A.abdef,B.opqrstuvwxyz"   sm:NO  iasm:NO  is:@"I-0.2,1.0"];            // delete one item from each of 2 sections
    [self assertTransitionFrom:@"A.abcdef,B.nopqrstuvwxyz"   to:@"A.abdef,B.nopqrstuvwxyz"  sm:NO  iasm:NO  is:@"I-0.2"];                // delete one item from a section
    [self assertTransitionFrom:@"A.ab,B.cde,C.fghijklmnop"   to:@"A.q,B.cde,C.rfghijklmnop" sm:NO  iasm:NO  is:@"I-0.0,0.1;I+0.0,2.0"];  // delete and insert different items
    [self assertTransitionFrom:@"A.a,B.bc,C.defg"            to:@"A.a,C.defg"               sm:NO  iasm:NO  is:@"S-1"];                  // delete middle section
    [self assertTransitionFrom:@"A.abc"                      to:@"A.bca"                    sm:NO  iasm:NO  is:@"S*0"];                  // have to reload section because reordered it
    [self assertTransitionFrom:@"A.abc,B.def"                to:@"B.def,A.abc"              sm:NO  iasm:NO  is:@"*"];                    // have to reload table
    [self assertTransitionFrom:@""                           to:@""                         sm:NO  iasm:NO  is:@""];                     // empty to empty

    // Moves allowed but none present
    [self assertTransitionFrom:@"A.ab,B.cde,C.fghijklmnop"   to:@"A.q,B.cde,C.rfghijklmnop" sm:YES iasm:YES is:@"I-0.0,0.1;I+0.0,2.0"];  // delete and insert different items

    // Moves allowed and present
    [self assertTransitionFrom:@"A.a,B.b"                    to:@"B.b,A.a"                  sm:YES iasm:YES is:@"S>0/1,1/0"];             // switch 2 sections
    [self assertTransitionFrom:@"A.a,B.b"                    to:@"B.d,A.abc"                sm:YES iasm:YES is:@"I-1.0;I+0.0,1.1,1.2;S>0/1,1/0"];   // note we didn't enable inte section moves here
    [self assertTransitionFrom:@"A.abc,B.def,C.ghi"          to:@"A.bac,C.ghi,B.def"        sm:YES iasm:YES is:@"S>1/2,2/1;I<0.0/0.1,0.1/0.0"]; // switch items 1st section, switch 2nd & 3rd sections
}

- (void)assertTransitionFrom:(NSString *)oldString to:(NSString *)newString sm:(BOOL)doSectionMoves iasm:(BOOL)doIntraSectionMoves is:(NSString *)output {
    SGListTransition *transition = [SGListTransition new];
    transition.doSectionMoves = doSectionMoves;
    transition.doIntraSectionMoves = doIntraSectionMoves;
    transition.fromSections = [self sectionsForString:oldString];
    transition.toSections = [self sectionsForString:newString];
    [transition computeOperations];
    XCTAssertEqualObjects(transition.description, output);
}

- (void)testCounts {
    [self assertCountsFrom:@""                           to:@"A.a"                      are:@[@0, @0, @1] ];              // insert one 1 item section
    [self assertCountsFrom:@"A.a"                        to:@""                         are:@[@0, @1, @0] ];              // delete one 1 item section
    [self assertCountsFrom:@""                           to:@"A.a,B.a"                  are:@[@0, @0, @2] ];              // insert two 1 item sections
    [self assertCountsFrom:@"A.a,B.abc"                  to:@""                         are:@[@0, @4, @0] ];              // delete two sections
    [self assertCountsFrom:@"A.abc"                      to:@"A.bca"                    are:@[@3, @0, @0] ];              // have to reload section because reordered it
    [self assertCountsFrom:@"A.abcdef,B.nopqrstuvwxyz"   to:@"A.abdef,B.nopqrstuvwxyz"  are:@[@0, @1, @0] ];              // delete one item from a section
}

- (void)assertCountsFrom:(NSString *)oldString to:(NSString *)newString are:(NSArray<NSNumber *> *)output {
    SGListTransition *transition = [self transitionFrom:oldString to:newString];
    SGListTransitionCounts counts = [transition counts];
    XCTAssertEqual(counts.countItemsReloaded, output[0].integerValue);
    XCTAssertEqual(counts.countItemsDeleted, output[1].integerValue);
    XCTAssertEqual(counts.countItemsInserted, output[2].integerValue);
}

- (void)testExtractMoveSectionOperationsToBeforeTransition {
    {
        // Move section and also move an item inside a section
        SGListTransition *transition = [SGListTransition new];
        transition.doSectionMoves = YES;
        transition.doIntraSectionMoves = YES;
        transition.fromSections = [self sectionsForString:@"A.a,B.bcd"];
        // middle state:                                  @"B.bcd,A.a"
        transition.toSections =   [self sectionsForString:@"B.cbd,A.a"];
        [transition computeOperations];
        NSArray<SGListTransition *> *transitions = [transition extractMoveSectionOperationsToBeforeTransition];
        XCTAssertEqual(transitions.count, 2);
        XCTAssertEqualObjects(transitions[0].description, @"S>0/1,1/0");
        XCTAssertEqualObjects(transitions[1].description, @"I<0.0/0.1,0.1/0.0");
    }

    {
        // Move section in the presence of section inserts and deletes, resulting in the max 4 transitions
        SGListTransition *transition = [SGListTransition new];
        transition.doSectionMoves = YES;
        transition.doIntraSectionMoves = YES;
        transition.fromSections = [self sectionsForString:@"A.a,B.b,C.c,D.d"];
        // middle state 1:                                @"A.a,B.b,C.c,D.d,E."
        // middle state 2:                                @"A.a,B.b,D.d,C.c,E."
        // middle state 3:                                @"A.,B.b,D.d,C.cf,E.e"
        transition.toSections =   [self sectionsForString:@"B.b,D.d,C.cf,E.e"];
        [transition computeOperations];
        NSArray<SGListTransition *> *transitions = [transition extractMoveSectionOperationsToBeforeTransition];

        XCTAssertEqual(transitions.count, 4);

        XCTAssertEqualObjects(transitions[0].description, @"S+4");
        XCTAssertEqualObjects(transitions[1].description, @"S>2/3,3/2");
        XCTAssertEqualObjects(transitions[2].description, @"I-0.0;I+3.1,4.0");
        XCTAssertEqualObjects(transitions[3].description, @"S-0");

        XCTAssertEqualObjects([self stringForSections:transitions[0].fromSections], @"A.a,B.b,C.c,D.d");
        XCTAssertEqualObjects([self stringForSections:transitions[0].toSections],   @"A.a,B.b,C.c,D.d,E.");
        XCTAssertEqualObjects([self stringForSections:transitions[1].fromSections], @"A.a,B.b,C.c,D.d,E.");
        XCTAssertEqualObjects([self stringForSections:transitions[1].toSections],   @"A.a,B.b,D.d,C.c,E.");
        XCTAssertEqualObjects([self stringForSections:transitions[2].fromSections], @"A.a,B.b,D.d,C.c,E.");
        XCTAssertEqualObjects([self stringForSections:transitions[2].toSections],   @"A.,B.b,D.d,C.cf,E.e");
        XCTAssertEqualObjects([self stringForSections:transitions[3].fromSections], @"A.,B.b,D.d,C.cf,E.e");
        XCTAssertEqualObjects([self stringForSections:transitions[3].toSections],   @"B.b,D.d,C.cf,E.e");
    }
}

- (void)testConvertInsertDeletePairsToInterSectionMoves {
    [self assertTransitionWithConvertFrom:@"A.abc,B.def"           to:@"A.ac,B.defb"         is:@"I>0.1/1.3"];            // move item from one section to another
    [self assertTransitionWithConvertFrom:@"A.ab"                  to:@"A.a,B.b"             is:@"S+1;I>0.1/1.0"];        // move item to new section
    [self assertTransitionWithConvertFrom:@"A.a,B.b"               to:@"B.ab"                is:@"S-0;I>0.0/0.0"];        // move item from section that goes away
    [self assertTransitionWithConvertFrom:@"A.a"                   to:@"B.a"                 is:@"S-0;S+0;I>0.0/0.0"];    // move with old section go away new section insert
    [self assertTransitionWithConvertFrom:@"A.a,B.bdefghijck"      to:@"B.bdefghijck,A.a"    is:@"*"];                    // have to reload table
}

- (void)assertTransitionWithConvertFrom:(NSString *)oldString to:(NSString *)newString is:(NSString *)output {
    SGListTransition *transition = [self transitionFrom:oldString to:newString];
    [transition convertInsertDeletePairsToInterSectionMoves];
    XCTAssertEqualObjects(transition.description, output);
}

- (void)testExtractInsertDeleteSectionOperationsToNewTransitions {
    {
        // Insert one section after
        SGListTransition *transition = [self transitionFrom:@"A.ab" to:@"A.a,B.b"];                          // middle state A.ab,B
        NSArray<SGListTransition *> *transitions = [transition extractInsertDeleteSectionOperationsToNewTransitions];
        XCTAssertEqual(transitions.count, 2);
        XCTAssertEqualObjects(transitions[0].description, @"S+1");          // new before transition should be added
        XCTAssertEqualObjects(transitions[1].description, @"I-0.1;I+1.0");
    }

    {
        // Insert one section before
        SGListTransition *transition = [self transitionFrom:@"A.ab" to:@"B.b,A.a"];                          // middle state B,A.ab
        NSArray<SGListTransition *> *transitions = [transition extractInsertDeleteSectionOperationsToNewTransitions];
        XCTAssertEqual(transitions.count, 2);
        XCTAssertEqualObjects(transitions[0].description, @"S+0");         // new before transition should be added
        XCTAssertEqualObjects(transitions[1].description, @"I-1.1;I+0.0");
    }

    {
        // Delete one section before
        SGListTransition *transition = [self transitionFrom:@"A.a,B.b" to:@"B.ab"];                           // middle state A,B.ab
        NSArray<SGListTransition *> *transitions = [transition extractInsertDeleteSectionOperationsToNewTransitions];
        XCTAssertEqual(transitions.count, 2);
        XCTAssertEqualObjects(transitions[0].description, @"I-0.0;I+1.0");
        XCTAssertEqualObjects(transitions[1].description, @"S-0");         // new after transition should be added
    }

    {
        // Both insert and delete
        SGListTransition *transition = [self transitionFrom:@"A.a" to:@"B.a"];                                 // middle states B.,A.a then B.a,A.
        NSArray<SGListTransition *> *transitions = [transition extractInsertDeleteSectionOperationsToNewTransitions];
        XCTAssertEqual(transitions.count, 3);
        XCTAssertEqualObjects(transitions[0].description, @"S+0");         // new before transition should be added
        XCTAssertEqualObjects(transitions[1].description, @"I-1.0;I+0.0");
        XCTAssertEqualObjects(transitions[2].description, @"S-1");         // new after transition should be added

        [transitions[1] convertInsertDeletePairsToInterSectionMoves];
        XCTAssertEqualObjects(transitions[1].description, @"I>1.0/0.0");
    }

    {
        // Both insert and delete -- more complex
        SGListTransition *transition = [self transitionFrom:@"A.ab,B.cd,C.ef,D.gh" to:@"E.i,B.acd,C.ef,F.b"];  // middle states E.,A.ab,B.cd,C.ef,F.,D.gh then E.i,A.,B.acd,C.ef,F.b,D.
        NSArray<SGListTransition *> *transitions = [transition extractInsertDeleteSectionOperationsToNewTransitions];
        XCTAssertEqual(transitions.count, 3);
        XCTAssertEqualObjects(transitions[0].description, @"S+0,4");       // new before transition should be added
        XCTAssertEqualObjects(transitions[1].description, @"I-1.0,1.1,5.0,5.1;I+0.0,2.0,4.0");
        XCTAssertEqualObjects(transitions[2].description, @"S-1,5");       // new after transition should be added

        [transitions[1] convertInsertDeletePairsToInterSectionMoves];
        XCTAssertEqualObjects(transitions[1].description, @"I-5.0,5.1;I+0.0;I>1.0/2.0,1.1/4.0");
    }

    {
        // Both insert and delete, but in the presence of section moves
        SGListTransition *transition = [SGListTransition new];
        transition.doSectionMoves = YES;
        transition.doIntraSectionMoves = YES;
        transition.fromSections = [self sectionsForString:@"A.abc,B.def,C.ghi,D.jkl"];
        // middle state 1:                                @"A.abc,B.def,C.ghi,D.jkl,E."            // after insert section
        // middle state 2:                                @"A.abcz,D.jkl,C.,B.def,E.mno"           // after all other operations
        transition.toSections =   [self sectionsForString:@"A.abcz,D.jkl,B.def,E.mno"];            // after delete section
        [transition computeOperations];
        NSArray<SGListTransition *> *transitions = [transition extractInsertDeleteSectionOperationsToNewTransitions];

        XCTAssertEqual(transitions.count, 3);

        XCTAssertEqualObjects(transitions[0].description, @"S+4");
        XCTAssertEqualObjects(transitions[1].description, @"I-2.0,2.1,2.2;I+0.3,4.0,4.1,4.2;S>1/3,3/1");
        XCTAssertEqualObjects(transitions[2].description, @"S-2");

        XCTAssertEqualObjects([self stringForSections:transitions[0].fromSections], @"A.abc,B.def,C.ghi,D.jkl");
        XCTAssertEqualObjects([self stringForSections:transitions[0].toSections],   @"A.abc,B.def,C.ghi,D.jkl,E.");
        XCTAssertEqualObjects([self stringForSections:transitions[1].fromSections], @"A.abc,B.def,C.ghi,D.jkl,E.");
        XCTAssertEqualObjects([self stringForSections:transitions[1].toSections],   @"A.abcz,D.jkl,C.,B.def,E.mno");
        XCTAssertEqualObjects([self stringForSections:transitions[2].fromSections], @"A.abcz,D.jkl,C.,B.def,E.mno");
        XCTAssertEqualObjects([self stringForSections:transitions[2].toSections],   @"A.abcz,D.jkl,B.def,E.mno");
    }

    {
        // Both insert and delete, but in the presence of section moves, different setup
        SGListTransition *transition = [SGListTransition new];
        transition.doSectionMoves = YES;
        transition.doIntraSectionMoves = YES;
        transition.fromSections = [self sectionsForString:@"A.a,B.b,C.c,D.d,E.e,F.f"];
        // middle state 1:                                @"A.a,B.b,C.c,D.d,E.e,G.,F.f"           // after insert section
        // middle state 2:                                @"A.,F.f,B.b,C.c,D.d,G.g,E.e"           // after all other operations
        transition.toSections =   [self sectionsForString:@"F.f,B.b,C.c,D.d,G.g,E.e"];            // after delete section
        [transition computeOperations];
        NSLog(@"transition operations before extraction: %@", transition);
        NSArray<SGListTransition *> *transitions = [transition extractInsertDeleteSectionOperationsToNewTransitions];

        XCTAssertEqual(transitions.count, 3);

        XCTAssertEqualObjects(transitions[0].description, @"S+5");
        XCTAssertEqualObjects(transitions[1].description, @"I-0.0;I+5.0;S>1/2,2/3,3/4,4/6,6/1");
        XCTAssertEqualObjects(transitions[2].description, @"S-0");

        XCTAssertEqualObjects([self stringForSections:transitions[0].fromSections], @"A.a,B.b,C.c,D.d,E.e,F.f");
        XCTAssertEqualObjects([self stringForSections:transitions[0].toSections],   @"A.a,B.b,C.c,D.d,E.e,G.,F.f");
        XCTAssertEqualObjects([self stringForSections:transitions[1].fromSections], @"A.a,B.b,C.c,D.d,E.e,G.,F.f");
        XCTAssertEqualObjects([self stringForSections:transitions[1].toSections],   @"A.,F.f,B.b,C.c,D.d,G.g,E.e");
        XCTAssertEqualObjects([self stringForSections:transitions[2].fromSections], @"A.,F.f,B.b,C.c,D.d,G.g,E.e");
        XCTAssertEqualObjects([self stringForSections:transitions[2].toSections],   @"F.f,B.b,C.c,D.d,G.g,E.e");
    }

    {
        SGListTransition *transition = [SGListTransition new];
        transition.doSectionMoves = YES;
        transition.fromSections = [self sectionsForString:@"C.c,D.d"];
        // middle state 1:                                @"A.,B.,C.c,D.d"            // after insert section
        // middle state 2:                                @"A.a,B.b,C.c,D."           // after all other operations
        transition.toSections =   [self sectionsForString:@"A.a,B.b,C.c"];            // after delete section
        [transition computeOperations];
        NSLog(@"transition operations before extraction: %@", transition);
        NSArray<SGListTransition *> *transitions = [transition extractInsertDeleteSectionOperationsToNewTransitions];

        XCTAssertEqual(transitions.count, 3);

        XCTAssertEqualObjects(transitions[0].description, @"S+0,1");
        XCTAssertEqualObjects(transitions[1].description, @"I-3.0;I+0.0,1.0");
        XCTAssertEqualObjects(transitions[2].description, @"S-3");

        XCTAssertEqualObjects([self stringForSections:transitions[0].fromSections], @"C.c,D.d");
        XCTAssertEqualObjects([self stringForSections:transitions[0].toSections],   @"A.,B.,C.c,D.d");
        XCTAssertEqualObjects([self stringForSections:transitions[1].fromSections], @"A.,B.,C.c,D.d");
        XCTAssertEqualObjects([self stringForSections:transitions[1].toSections],   @"A.a,B.b,C.c,D.");
        XCTAssertEqualObjects([self stringForSections:transitions[2].fromSections], @"A.a,B.b,C.c,D.");
        XCTAssertEqualObjects([self stringForSections:transitions[2].toSections],   @"A.a,B.b,C.c");
    }
}

#pragma mark - SGListTransition private methods

- (void)testMoveSectionsInArrayToMatchArray {
    [self assertMoveSections:@"A,B"     in:@"A,B"               matching:@"A,B"               is:@"A,B"               changed:NO];
    [self assertMoveSections:@"A"       in:@"A,B,C"             matching:@"C,B,A"             is:@"B,C,A"             changed:YES];
    [self assertMoveSections:@"A,B,C"   in:@"B,C,A"             matching:@"A,B,C"             is:@"A,B,C"             changed:YES];
    [self assertMoveSections:@"G,H,I"   in:@"A,B,C,D,E,F,G,H,I" matching:@"A,C,G,E,H,F,I,B,D" is:@"A,B,G,C,H,D,I,E,F" changed:YES];
}

- (void)assertMoveSections:(NSString *)sectionsString in:(NSString *)inSectionsString matching:(NSString *)matchingSectionsString is:(NSString *)expectedSectionsString changed:(BOOL)expectedChanged {
    NSArray<SGListSection *> *sections = [self sectionsForString:sectionsString];
    NSMutableArray<SGListSection *> *inSections = [self sectionsForString:inSectionsString].mutableCopy;
    NSArray<SGListSection *> *matchingSections = [self sectionsForString:matchingSectionsString];
    NSArray<SGListSection *> *expectedSections = [self sectionsForString:expectedSectionsString];

    BOOL changed = [SGListTransition moveSections:sections inArray:inSections toMatchArray:matchingSections];
    XCTAssertEqualObjects(inSections, expectedSections);
    XCTAssertEqual(changed, expectedChanged);
}

#pragma mark - SGArrayDiff public methods

- (void)testDiffFromArrayToArrayIncludeUnchanged {
    // No moves
    [self assertArrayDiffFrom:@"01234"          to:@"01234"          moves:NO          unchanged:NO   is:@""];
    [self assertArrayDiffFrom:@"01234"          to:@"1234"           moves:NO          unchanged:NO   is:@"-0"];
    [self assertArrayDiffFrom:@""               to:@"01234"          moves:NO          unchanged:NO   is:@"+0,1,2,3,4"];
    [self assertArrayDiffFrom:@"012345"         to:@"13579"          moves:NO          unchanged:NO   is:@"-0,2,4;+3,4"];
    [self assertArrayDiffFrom:@"012345"         to:@"13579"          moves:NO          unchanged:YES  is:@"=1,3,5;-0,2,4;+3,4"];
    [self assertArrayDiffFrom:@"01234"          to:@"43210"          moves:NO          unchanged:NO   is:nil];      // cannot compute diff due to reordering
    [self assertArrayDiffFrom:@"012234"         to:@"01234"          moves:NO          unchanged:NO   is:nil];      // cannot compute diff due to duplicates
    [self assertArrayDiffFrom:@""               to:@""               moves:NO          unchanged:NO   is:@""];

    // Moves allowed, but none present
    [self assertArrayDiffFrom:@"012345"         to:@"13579"          moves:YES         unchanged:NO   is:@"-0,2,4;+3,4"];
    [self assertArrayDiffFrom:@"012345"         to:@"13579"          moves:YES         unchanged:YES  is:@"=1,3,5;-0,2,4;+3,4"];

    // Moves allowed and present
    [self assertArrayDiffFrom:@"01234"          to:@"10234"          moves:YES         unchanged:NO   is:@">0/1,1/0"];
    [self assertArrayDiffFrom:@"01234"          to:@"40123"          moves:YES         unchanged:NO   is:@">0/1,1/2,2/3,3/4,4/0"];
    [self assertArrayDiffFrom:@"01234"          to:@"43210"          moves:YES         unchanged:NO   is:@">0/4,1/3,3/1,4/0"];
    [self assertArrayDiffFrom:@"01234"          to:@"10235"          moves:YES         unchanged:NO   is:@"-4;+4;>0/1,1/0"];
    [self assertArrayDiffFrom:@"01"             to:@"102"            moves:YES         unchanged:NO   is:@"+2;>0/1,1/0"];
}

- (void)assertArrayDiffFrom:(NSString *)oldString to:(NSString *)newString moves:(BOOL)doMoves unchanged:(BOOL)includeUnchanged is:(NSString *)output {
    NSArray *oldArray = [self divideStringIntoCharacters:oldString];
    NSArray *newArray = [self divideStringIntoCharacters:newString];
    SGArrayDiff *arrayDiff = [SGArrayDiff diffFromArray:oldArray toArray:newArray doMoves:doMoves includeUnchanged:includeUnchanged];
    XCTAssertEqualObjects(arrayDiff.description, output);
}

#pragma mark - Helpers

- (SGListTransition *)transitionFrom:(NSString *)oldString to:(NSString *)newString {
    SGListTransition *transition = [SGListTransition new];
    transition.fromSections = [self sectionsForString:oldString];
    transition.toSections = [self sectionsForString:newString];
    [transition computeOperations];
    return transition;
}

- (NSArray<SGListSection *> *)sectionsForString:(NSString *)input {
    NSMutableArray<SGListSection *> *sections = [NSMutableArray new];
    for (NSString *sectionString in [self splitString:input byString:@","]) {
        NSArray<NSString *> *titleAndItems = [self splitString:sectionString byString:@"."];
        SGListSection *section = [SGListSection new];
        section.title = titleAndItems[0];
        if (titleAndItems.count > 1) {
            section.items = [self divideStringIntoCharacters:titleAndItems[1]];
        } else {
            section.items = @[];
        }
        [sections addObject:section];
    }
    return sections;
}

- (NSString *)stringForSections:(NSArray<SGListSection *> *)inputSections {
    NSMutableArray *sectionStrings = [NSMutableArray new];
    for (SGListSection *section in inputSections) {
        NSString *sectionString = [NSString stringWithFormat:@"%@.%@", section.title, [section.items componentsJoinedByString:@""]];
        [sectionStrings addObject:sectionString];
    }
    return [sectionStrings componentsJoinedByString:@","];
}

- (NSArray<NSString *> *)splitString:(NSString *)input byString:(NSString *)separator {
    if (input.length == 0) {
        return @[];
    }
    return [input componentsSeparatedByString:separator];
}

- (NSArray<NSString *> *)divideStringIntoCharacters:(NSString *)input {
    NSMutableArray *output = [NSMutableArray new];
    for (NSInteger i = 0; i < input.length; ++i) {
        NSString *character = [input substringWithRange:NSMakeRange(i, 1)];
        [output addObject:character];
    }
    return output;
}

@end
