//
//  SGListAnimator.m
//  SeatGeek
//
//  Created by David McNerney on 12/21/15.
//  Copyright © 2015 SeatGeek. All rights reserved.
//

#import "SGListAnimator_ForUnitTests.h"
#import "SGListSection.h"
#import "SGListTransition.h"


@implementation SGListAnimator

#pragma mark - Convenience class methods

+ (BOOL)transitionTableView:(UITableView *)tableView
               fromSections:(NSArray<SGListSection *> *)oldSections
                 toSections:(NSArray<SGListSection *> *)newSections {

    SGListAnimator *animator = [SGListAnimator new];
    animator.tableView = tableView;
    animator.currentSections = oldSections;
    return [animator transitionTableViewToSections:newSections];
}

+ (BOOL)transitionTableView:(UITableView *)tableView
           fromSectionItems:(NSArray<NSArray *> *)oldSectionItems
                     titles:(NSArray<NSString *> *)oldTitles
             toSectionItems:(NSArray<NSArray *> *)newSectionItems
                     titles:(NSArray<NSString *> *)newTitles {

    NSMutableArray<SGListSection *> *oldSections = [NSMutableArray new];
    for (NSInteger i = 0; i < MIN(oldSectionItems.count, oldTitles.count); ++i) {
        SGListSection *oldSection = [SGListSection new];
        oldSection.title = oldTitles[i];
        oldSection.items = oldSectionItems[i];
        [oldSections addObject:oldSection];
    }

    NSMutableArray<SGListSection *> *newSections = [NSMutableArray new];
    for (NSInteger i = 0; i < MIN(newSectionItems.count, newTitles.count); ++i) {
        SGListSection *newSection = [SGListSection new];
        newSection.title = newTitles[i];
        newSection.items = newSectionItems[i];
        [newSections addObject:newSection];
    }

    return [self transitionTableView:tableView fromSections:oldSections toSections:newSections];
}

+ (BOOL)transitionCollectionView:(UICollectionView *)collectionView
                    fromSections:(NSArray<SGListSection *> *)oldSections
                      toSections:(NSArray<SGListSection *> *)newSections {

    SGListAnimator *animator = [SGListAnimator new];
    animator.collectionView = collectionView;
    animator.currentSections = oldSections;
    return [animator transitionCollectionViewToSections:newSections];
}

+ (BOOL)transitionCollectionView:(UICollectionView *)collectionView
                fromSectionItems:(NSArray<NSArray *> *)oldSectionItems
                          titles:(NSArray<NSString *> *)oldTitles
                  toSectionItems:(NSArray<NSArray *> *)newSectionItems
                          titles:(NSArray<NSString *> *)newTitles {

    NSMutableArray<SGListSection *> *oldSections = [NSMutableArray new];
    for (NSInteger i = 0; i < MIN(oldSectionItems.count, oldTitles.count); ++i) {
        SGListSection *oldSection = [SGListSection new];
        oldSection.title = oldTitles[i];
        oldSection.items = oldSectionItems[i];
        [oldSections addObject:oldSection];
    }

    NSMutableArray<SGListSection *> *newSections = [NSMutableArray new];
    for (NSInteger i = 0; i < MIN(newSectionItems.count, newTitles.count); ++i) {
        SGListSection *newSection = [SGListSection new];
        newSection.title = newTitles[i];
        newSection.items = newSectionItems[i];
        [newSections addObject:newSection];
    }

    return [self transitionCollectionView:collectionView fromSections:oldSections toSections:newSections];
}

#pragma mark - Transition methods

- (BOOL)transitionTableViewToSections:(NSArray<SGListSection *> *)newSections {
    if (!self.tableView.dataSource || !self.tableView.delegate) {
        // Either table view is not completely set up, or else we've started some
        // dealloc time cleanup already. Either way, not safe to try to animate
        // the table.
        return NO;
    }

    //NSLog(@"Transitioning table view from %@ to %@", [self stringForSections:self.currentSections], [self stringForSections:newSections]);

    if (!self.currentSections) {
        // First time we are called, no before data, so no transition possible.
        self.currentSections = newSections;
        [self.tableView reloadData];    // just in case the table view loaded up before this time
        return NO;
    }

    if ([newSections isEqual:self.currentSections]) {
        // Sections and their contents haven't changed. This counts as a successful animated transition,
        // so return true. Note that we still update our currentSections -- even though the *identities*
        // of the items in the sections haven't changed, the item objects themselves may be new
        // objects in memory with updated details.
        //NSLog(@"     (no change)");
        self.currentSections = newSections;
        return YES;
    }

    NSArray<SGListTransition *> *transitions = [self.class transitionObjectsFromSections:self.currentSections
                                                                              toSections:newSections
                                                                          doSectionMoves:self.doSectionMoves
                                                                     doIntraSectionMoves:self.doIntraSectionMoves
                                                                     doInterSectionMoves:self.doInterSectionMoves];

    BOOL okTDoAnimatedTransition = YES;
    if (self.shouldAnimateTransitionsBlock && !self.shouldAnimateTransitionsBlock(transitions)) {
        okTDoAnimatedTransition = NO;
    }

    if (okTDoAnimatedTransition) {
        BOOL didAnimatedTransition = YES;
        //NSInteger step = 1;
        for (SGListTransition *transition in transitions) {
            //NSLog(@"     %li) %@ ---(%@)---> %@", (long)step++, [self stringForSections:transition.fromSections], transition.description, [self stringForSections:transition.toSections]);
            self.currentSections = transition.toSections;  // must be set before the animations are applied
            BOOL didAnimateThisStep = [transition applyToTableView:self.tableView];
            if (!didAnimateThisStep ) {
                didAnimatedTransition = NO;
            }
        }
        return didAnimatedTransition;
    } else {
        self.currentSections = newSections;
        [self.tableView reloadData];
        return NO;
    }
}

- (BOOL)transitionCollectionViewToSections:(NSArray<SGListSection *> *)newSections {
    if (!self.collectionView.dataSource || !self.collectionView.delegate) {
        // Either table view is not completely set up, or else we've started some
        // dealloc time cleanup already. Either way, not safe to try to animate
        // the table.
        return NO;
    }

    //NSLog(@"Transitioning collection view from %@ to %@", [self stringForSections:self.currentSections], [self stringForSections:newSections]);

    if (!self.currentSections) {
        // First time we are called, no before data, so no transition possible.
        self.currentSections = newSections;
        [self.collectionView reloadData];    // just in case the table view loaded up before this time
        return NO;
    }

    if ([newSections isEqual:self.currentSections]) {
        // Sections and their contents haven't changed. This counts as a successful animated transition,
        // so return true. Note that we still update our currentSections -- even though the *identities*
        // of the items in the sections haven't changed, the item objects themselves may be new
        // objects in memory with updated details.
        //NSLog(@"     (no change)");
        self.currentSections = newSections;
        return YES;
    }

    NSArray<SGListTransition *> *transitions = [self.class transitionObjectsFromSections:self.currentSections
                                                                              toSections:newSections
                                                                          doSectionMoves:self.doSectionMoves
                                                                     doIntraSectionMoves:self.doIntraSectionMoves
                                                                     doInterSectionMoves:self.doInterSectionMoves];

    BOOL didAnimatedTransition = YES;
    //NSInteger step = 1;
    for (SGListTransition *transition in transitions) {
        //NSLog(@"     %li) %@ ---(%@)---> %@", (long)step++, [self stringForSections:transition.fromSections], transition.description, [self stringForSections:transition.toSections]);
        self.currentSections = transition.toSections;  // must be set before the animations are applied
        BOOL didAnimateThisStep = [transition applyToCollectionView:self.collectionView];
        if (!didAnimateThisStep ) {
            didAnimatedTransition = NO;
        }
    }
    return didAnimatedTransition;
}

#pragma mark - Utility & misc

+ (SGListTransitionCounts)totalCountsForTransitions:(NSArray<SGListTransition *> *)transitions {
    SGListTransitionCounts totalCounts = (SGListTransitionCounts) {
        .countItemsReloaded = 0,
        .countItemsDeleted = 0,
        .countItemsInserted = 0
    };
    for (SGListTransition *transition in transitions) {
        SGListTransitionCounts counts = [transition counts];
        totalCounts.countItemsReloaded += counts.countItemsReloaded;
        totalCounts.countItemsDeleted += counts.countItemsDeleted;
        totalCounts.countItemsInserted += counts.countItemsInserted;
    };
    return totalCounts;
}

#pragma mark - Private

/**
 * Computes the operations necessary to go from the from section list to the to section list, and
 * returns one or more SGListTransition objects containing them. UITableView and UICollectionView place
 * some limits on the types of animation operations that can be grouped together in a single transition,
 * so multiple transitions are returned in some situations, to avoid placing incompatible operations in
 * the same transition.
 */
+ (NSArray<SGListTransition *> *)transitionObjectsFromSections:(NSArray<SGListSection *> *)oldSections
                                                    toSections:(NSArray<SGListSection *> *)newSections
                                                doSectionMoves:(BOOL)doSectionMoves
                                           doIntraSectionMoves:(BOOL)doIntraSectionMoves
                                           doInterSectionMoves:(BOOL)doInterSectionMoves {

    NSArray<SGListTransition *> *transitions = @[];

    // Create our base transition.
    SGListTransition *baseTransition = [SGListTransition new];
    baseTransition.doSectionMoves = doSectionMoves;
    baseTransition.doIntraSectionMoves = doIntraSectionMoves;
    baseTransition.fromSections = oldSections;
    baseTransition.toSections = newSections;
    [baseTransition computeOperations];
    transitions = @[ baseTransition ];

    // This base transition contains all the operations needed to go from oldSections to newSections,
    // logically speaking, and often that's all we need. However, UITableView and UICollectionView
    // place certain limits on what operations may be performed together, so we may need to extract some operations
    // out to separate transitions. Also, -computeOperations creates inter-section moves as insert/delete pairs,
    // so if doInterSectionMoves is true, we'll need to convert those pairs to move operations.

    // Section moves need to be separated from at least some other types of operations. Currently,
    // we play it safe & separate if anything else is happening at all.
    if (baseTransition.sectionMoveTuples.count > 0 &&
        baseTransition.hasOperationsOtherThanSectionMoves) {

        NSArray<SGListTransition *> *newTransitions = [baseTransition extractMoveSectionOperationsToBeforeTransition];
        transitions = [SGListTransition inArray:transitions replaceObject:baseTransition withObjects:newTransitions];
    }

    // Now that we've separated out any section moves, we turn off doSectionMoves in our base transition,
    // so that if we have to re-invoke -computeOperations on it as part of other extractions below,
    // issues with how we extract won't cause section moves to re-appear.
    baseTransition.doSectionMoves = NO;

    // Handle inter section moves if required
    if (doInterSectionMoves && baseTransition.isAnimatable) {
        [baseTransition convertInsertDeletePairsToInterSectionMoves];

        // UITableView cannot handle moves to new sections or moves out of sections that are going away
        // in a single transition, so if we have delete/insert section operations and inter section moves,
        // we separate out the delete and insert section operations to new transitions.
        if (baseTransition.interSectionMoveTuples.count > 0 &&
            (baseTransition.deleteSectionsInOld.count > 0 || baseTransition.insertSectionsInNew.count > 0)) {

            NSArray<SGListTransition *> *newTransitions = [baseTransition extractInsertDeleteSectionOperationsToNewTransitions];
            transitions = [SGListTransition inArray:transitions replaceObject:baseTransition withObjects:newTransitions];
        }
    }

    return transitions;
}

- (NSString *)stringForSections:(NSArray<SGListSection *> *)sections {
    if (sections.count > 0) {
        NSMutableArray *sectionDescriptions = [NSMutableArray new];
        for (SGListSection *section in sections) {
            NSString *description = [NSString stringWithFormat:@"%@.%@", section.identifier, [section.items componentsJoinedByString:@""]];
            [sectionDescriptions addObject:description];
        }
        return [sectionDescriptions componentsJoinedByString:@","];
    } else {
        return @"0";
    }
}

@end
