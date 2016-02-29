//
//  SGListTransition.m
//  SeatGeek
//
//  Created by David McNerney on 12/22/15.
//  Copyright © 2015 SeatGeek. All rights reserved.
//

#import "SGListTransition.h"
#import "SGListSection.h"
#import "SGArrayDiff.h"
#import "SGIndexTuple.h"
#import "SGIndexPathTuple.h"


/// Used internally by -moveSections:inArray:toMatchArray:
@interface SGSectionAndIndexTuple : NSObject
@property (nonatomic) SGListSection *section;
@property (nonatomic) NSInteger index;
@end
@implementation SGSectionAndIndexTuple
@end


@implementation SGListTransition

#pragma mark - Computing

- (void)computeOperations {
    // First, determine how the sections have changed.
    NSMutableArray *oldSectionIdentifiers = [NSMutableArray new];
    for (SGListSection *oldSection in self.fromSections) {
        [oldSectionIdentifiers addObject:oldSection.identifier];
    }
    NSMutableArray *newSectionIdentifiers = [NSMutableArray new];
    for (SGListSection *newSection in self.toSections) {
        [newSectionIdentifiers addObject:newSection.identifier];
    }
    SGArrayDiff *sectionsDiff = [SGArrayDiff diffFromArray:oldSectionIdentifiers toArray:newSectionIdentifiers doMoves:self.doSectionMoves includeUnchanged:YES];

    if (sectionsDiff) {
        // We were able to determine a diff for the sections, so we can proceed with gathering our operations.

        // From our diff of the sections, right away we have our delete and insert section
        // operations.
        self.deleteSectionsInOld = [self.class indexSetForIndices:sectionsDiff.deleteInOld];
        self.insertSectionsInNew = [self.class indexSetForIndices:sectionsDiff.insertInNew];
        self.sectionMoveTuples = sectionsDiff.moved;

        // For sections that weren't deleted/inserted, but are present both before and after, we need to get
        // the row insert/delete operations. What we do here inside this loop is analogous
        // to what we did above for the sections: get an array diff and then add insert / delete operations
        // based on it, or indicate a reload if we couldn't get a diff.
        //
        NSMutableArray<NSNumber *> *reloadSectionsInOld = [NSMutableArray array];
        NSMutableArray<NSIndexPath *> *deleteItemsInOld = [NSMutableArray array];
        NSMutableArray<NSIndexPath *> *insertItemsInNew = [NSMutableArray array];
        NSMutableArray<SGIndexPathTuple *> *intraSectionMoveTuples = [NSMutableArray array];
        NSArray<SGIndexTuple *> *movedAndUnchanged = [sectionsDiff.moved arrayByAddingObjectsFromArray:sectionsDiff.unchanged];
        for (SGIndexTuple *indexTuple in movedAndUnchanged) {
            // Determine indices for this section in old and new, get the items
            // for old and new, and then do an array diff to find out how the items
            // have changed.
            NSInteger oldSectionIndex = indexTuple.indexInOld;
            NSArray *oldItems = self.fromSections[oldSectionIndex].items;
            NSInteger newSectionIndex = indexTuple.indexInNew;
            NSArray *newItems = self.toSections[newSectionIndex].items;
            SGArrayDiff *itemsDiff = [SGArrayDiff diffFromArray:oldItems toArray:newItems doMoves:self.doIntraSectionMoves includeUnchanged:NO];

            if (itemsDiff) {
                // We could get a diff
                for (NSNumber *oldIndexToDelete in itemsDiff.deleteInOld) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:oldIndexToDelete.integerValue inSection:oldSectionIndex];
                    [deleteItemsInOld addObject:indexPath];
                }
                for (NSNumber *newIndexToInsert in itemsDiff.insertInNew) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:newIndexToInsert.integerValue inSection:newSectionIndex];
                    [insertItemsInNew addObject:indexPath];
                }
                for (SGIndexTuple *moveIndexTuple in itemsDiff.moved) {
                    NSIndexPath *oldIndexPath = [NSIndexPath indexPathForItem:moveIndexTuple.indexInOld inSection:oldSectionIndex];
                    NSIndexPath *newIndexPath = [NSIndexPath indexPathForItem:moveIndexTuple.indexInNew inSection:newSectionIndex];
                    [intraSectionMoveTuples addObject:[SGIndexPathTuple withOld:oldIndexPath new:newIndexPath]];
                }
            } else {
                // We couldn't get a diff, so just have to add a reload operation. This happens if existing items
                // in the section were reordered.
                [reloadSectionsInOld addObject:@(oldSectionIndex)];
            }
        }
        self.reloadSectionsInOld = [self.class indexSetForIndices:reloadSectionsInOld];
        self.deleteItemsInOld = deleteItemsInOld;
        self.insertItemsInNew = insertItemsInNew;
        self.intraSectionMoveTuples = intraSectionMoveTuples;

        // These get added later, if -convertInsertDeletePairsToInterSectionMoves is called.
        self.interSectionMoveTuples = @[];
    } else {
        // We couldn't get a diff, so we just have to reload the section. This happens if existing
        // items in the section are reordered when self.doIntraSectionMoves is NO, or in the case of duplicate objects.
        // -isAnimatable will return no, and -applyToTableView: will just reload the table view if invoked.

        self.reloadSectionsInOld = nil;
        self.deleteSectionsInOld = nil;
        self.deleteItemsInOld = nil;
        self.insertSectionsInNew = nil;
        self.insertItemsInNew = nil;

        self.sectionMoveTuples = nil;
        self.intraSectionMoveTuples = nil;
        self.interSectionMoveTuples = nil;
    }
}

#pragma mark - Extracting transitions & converting operations

- (NSArray<SGListTransition *> *)extractMoveSectionOperationsToBeforeTransition {
    NSArray<SGListTransition *> *transitions = @[ self ];

    if (self.isAnimatable && self.sectionMoveTuples.count > 0) {
        // Insert and delete section operations would make it hard for us to keep the right indices in the work we
        // do below, so separate them out first.
        if (self.deleteSectionsInOld || self.insertSectionsInNew) {
            NSArray<SGListTransition *> *newTransitions = [self extractInsertDeleteSectionOperationsToNewTransitions];
            transitions = [SGListTransition inArray:transitions replaceObject:self withObjects:newTransitions];
        }

        // Create a new transition, to go just before this one, that has only the section moves
        SGListTransition *priorTransition = [SGListTransition new];
        priorTransition.fromSections = self.fromSections;
        priorTransition.sectionMoveTuples = self.sectionMoveTuples;

        priorTransition.reloadSectionsInOld = [NSIndexSet new];
        priorTransition.deleteSectionsInOld = [NSIndexSet new];
        priorTransition.deleteItemsInOld = @[];
        priorTransition.insertSectionsInNew = [NSIndexSet new];
        priorTransition.insertItemsInNew = @[];
        priorTransition.intraSectionMoveTuples = @[];
        priorTransition.interSectionMoveTuples = @[];

        // Figure out priorTransition.toSections, which will also be self.fromSections
        NSMutableDictionary<NSNumber *, NSNumber *> *oldIndices = [NSMutableDictionary new];
        for (SGIndexTuple *indexTuple in priorTransition.sectionMoveTuples) {
            oldIndices[@(indexTuple.indexInNew)] = @(indexTuple.indexInOld);
        }
        NSMutableArray<SGListSection *> *priorTransitionToSections = [NSMutableArray new];
        for (NSInteger newIndex = 0; newIndex < priorTransition.fromSections.count; ++newIndex) {
            NSInteger oldIndex = oldIndices[@(newIndex)] ? oldIndices[@(newIndex)].integerValue : newIndex;
            [priorTransitionToSections addObject:priorTransition.fromSections[oldIndex]];
        }
        priorTransition.toSections = priorTransitionToSections;

        // Update our fromSections, which means we need to recompute our operations
        self.fromSections = priorTransition.toSections;
        [self computeOperations];

        // If we figured out priorTransition.toSections / self.fromSections correctly above, then there should
        // have been no section moves detected by -computeOperations.
        NSAssert(self.sectionMoveTuples.count == 0, @"Expected no section moves in this transition after extracting them out");

        transitions = [SGListTransition inArray:transitions replaceObject:self withObjects:@[ priorTransition, self ]];
    }

    return transitions;
}

- (void)convertInsertDeletePairsToInterSectionMoves {
    if (!self.isAnimatable) {
        return;
    }

    // Here we want to identify deletes and inserts of the same object and replace them with moves. This
    // is made more complicated by the possibility that an item being moved could have been the last
    // item in its old section, in which case it would have shown up as a section delete, or the first
    // item in its new section, in which case it would have shown up as a section insert.

    NSMutableArray<NSIndexPath *> *deleteItemsInOldToRemove = [NSMutableArray new];
    NSMutableArray<NSIndexPath *> *insertItemsInNewToRemove = [NSMutableArray new];
    NSMutableArray<SGIndexPathTuple *> *moveTuples = [NSMutableArray new];

    // Loop through each inserted item and see if it comes from a delete
    for(NSIndexPath *newIndexPath in self.insertItemsInNew) {
        id newItem = self.toSections[newIndexPath.section].items[newIndexPath.item];

        BOOL didFind = NO;

        // Is this inserted item coming from a deleted item?
        for (NSIndexPath *oldIndexPath in self.deleteItemsInOld) {
            id oldItem = self.fromSections[oldIndexPath.section].items[oldIndexPath.item];
            if ([oldItem isEqual:newItem]) {
                [deleteItemsInOldToRemove addObject:oldIndexPath];
                [insertItemsInNewToRemove addObject:newIndexPath];

                SGIndexPathTuple *tuple = [SGIndexPathTuple withOld:oldIndexPath new:newIndexPath];
                [moveTuples addObject:tuple];
                didFind = YES;
                break;
            }
        }
        if (didFind) {
            continue;
        }

        // Is this inserted item coming from a deleted section?
        NSInteger oldSectionIndex = self.deleteSectionsInOld.firstIndex;
        while (oldSectionIndex != NSNotFound) {
            if ([self.fromSections[oldSectionIndex].items containsObject:newItem]) {
                [insertItemsInNewToRemove addObject:newIndexPath];

                NSInteger oldItemIndex = [self.fromSections[oldSectionIndex].items indexOfObject:newItem];
                NSIndexPath *oldIndexPath = [NSIndexPath indexPathForItem:oldItemIndex inSection:oldSectionIndex];
                SGIndexPathTuple *tuple = [SGIndexPathTuple withOld:oldIndexPath new:newIndexPath];
                [moveTuples addObject:tuple];
                break;
            }

            oldSectionIndex = [self.deleteSectionsInOld indexGreaterThanIndex:oldSectionIndex];
        }
    }

    // Loop through each inserted section and see if any of its items come from deletes.
    NSInteger newSectionIndex = self.insertSectionsInNew.firstIndex;
    while(newSectionIndex != NSNotFound) {
        for (NSInteger newItemIndex = 0; newItemIndex < self.toSections[newSectionIndex].items.count; ++newItemIndex) {
            id newItem = self.toSections[newSectionIndex].items[newItemIndex];
            NSIndexPath *newIndexPath = [NSIndexPath indexPathForItem:newItemIndex inSection:newSectionIndex];

            BOOL didFind = NO;

            // Is this item in our inserted section coming from a deleted item?
            for (NSIndexPath *oldIndexPath in self.deleteItemsInOld) {
                id oldItem = self.fromSections[oldIndexPath.section].items[oldIndexPath.item];
                if ([oldItem isEqual:newItem]) {
                    [deleteItemsInOldToRemove addObject:oldIndexPath];

                    SGIndexPathTuple *tuple = [SGIndexPathTuple withOld:oldIndexPath new:newIndexPath];
                    [moveTuples addObject:tuple];
                    didFind = YES;
                    break;
                }
            }
            if (didFind) {
                continue;
            }

            // Is this item in our inserted section coming from a deleted section?
            NSInteger oldSectionIndex = self.deleteSectionsInOld.firstIndex;
            while (oldSectionIndex != NSNotFound) {
                if ([self.fromSections[oldSectionIndex].items containsObject:newItem]) {
                    NSInteger oldItemIndex = [self.fromSections[oldSectionIndex].items indexOfObject:newItem];
                    NSIndexPath *oldIndexPath = [NSIndexPath indexPathForItem:oldItemIndex inSection:oldSectionIndex];
                    SGIndexPathTuple *tuple = [SGIndexPathTuple withOld:oldIndexPath new:newIndexPath];
                    [moveTuples addObject:tuple];
                    break;
                }

                oldSectionIndex = [self.deleteSectionsInOld indexGreaterThanIndex:oldSectionIndex];
            }
        }

        newSectionIndex = [self.insertSectionsInNew indexGreaterThanIndex:newSectionIndex];
    }

    if (moveTuples.count > 0) {
        NSMutableArray<NSIndexPath *> *deleteItemsInOld = self.deleteItemsInOld.mutableCopy;
        [deleteItemsInOld removeObjectsInArray:deleteItemsInOldToRemove];
        self.deleteItemsInOld = deleteItemsInOld;

        NSMutableArray<NSIndexPath *> *insertItemsInNew = self.insertItemsInNew.mutableCopy;
        [insertItemsInNew removeObjectsInArray:insertItemsInNewToRemove];
        self.insertItemsInNew = insertItemsInNew;
    }
    self.interSectionMoveTuples = moveTuples;
}

- (NSArray<SGListTransition *> *)extractInsertDeleteSectionOperationsToNewTransitions {
    if (!self.isAnimatable) {
        return @[ self ];
    }

    BOOL hadMoves = self.interSectionMoveTuples.count > 0;

    // Prepare to move insert section operations to a new before transition
    NSMutableArray<SGListSection *> *sectionsToInsertBefore;
    if (self.insertSectionsInNew.count > 0) {
        sectionsToInsertBefore = [NSMutableArray new];
        NSInteger insertIndexInNew = self.insertSectionsInNew.firstIndex;
        while (insertIndexInNew != NSNotFound) {
            SGListSection *emptySection = [SGListSection new];
            emptySection.identifier = self.toSections[insertIndexInNew].identifier;
            emptySection.items = @[];
            [sectionsToInsertBefore addObject:emptySection];

            insertIndexInNew = [self.insertSectionsInNew indexGreaterThanIndex:insertIndexInNew];
        }
    }

    // Prepare to move delete section operations to a new after transition
    NSMutableArray<SGListSection *> *sectionsToInsertAfter;
    if (self.deleteSectionsInOld.count > 0) {
        sectionsToInsertAfter = [NSMutableArray new];
        NSInteger deleteIndexInOld = self.deleteSectionsInOld.firstIndex;
        while (deleteIndexInOld != NSNotFound) {
            SGListSection *emptySection = [SGListSection new];
            emptySection.identifier = self.fromSections[deleteIndexInOld].identifier;
            emptySection.items = @[];
            [sectionsToInsertAfter addObject:emptySection];

            deleteIndexInOld = [self.deleteSectionsInOld indexGreaterThanIndex:deleteIndexInOld];
        }
    }

    // Set up the transitions. How we do this depends on which / both we have
    SGListTransition *beforeTransition, *afterTransition;
    if (sectionsToInsertBefore && !sectionsToInsertAfter) {
        // One before transition inserts our new sections
        beforeTransition = [SGListTransition new];
        beforeTransition.fromSections = self.fromSections;

        // We start by adding the new sections at the end
        NSMutableArray<SGListSection *> *beforeTransitionToSections = beforeTransition.fromSections.mutableCopy;
        [beforeTransitionToSections addObjectsFromArray:sectionsToInsertBefore];

        // Then move them into their correct positions, which we have from self.toSections
        [self.class moveSections:sectionsToInsertBefore inArray:beforeTransitionToSections toMatchArray:self.toSections];

        // Set up all the states. Obviously, beforeTransition.toSections must be the same as self.fromSections.
        beforeTransition.toSections = beforeTransitionToSections;
        self.fromSections = beforeTransition.toSections;
    } else if (sectionsToInsertAfter && !sectionsToInsertBefore) {
        // One after transition deletes the sections that must go away
        afterTransition = [SGListTransition new];
        afterTransition.toSections = self.toSections;

        // We start by adding the new sections at the end
        NSMutableArray<SGListSection *> *afterTransitionFromSections = afterTransition.toSections.mutableCopy;
        [afterTransitionFromSections addObjectsFromArray:sectionsToInsertAfter];

        // Then move them into their correct positions, which we have from self.fromSections
        [self.class moveSections:sectionsToInsertAfter inArray:afterTransitionFromSections toMatchArray:self.fromSections];

        // Set up all the states.
        afterTransition.fromSections = afterTransitionFromSections;
        self.toSections = afterTransition.fromSections;
    } else if (sectionsToInsertBefore && sectionsToInsertAfter) {
        // We have section inserts and deletes both, so we separate out both a before transition and an after
        beforeTransition = [SGListTransition new];
        beforeTransition.fromSections = self.fromSections;
        afterTransition = [SGListTransition new];
        afterTransition.toSections = self.toSections;

        // Add on the new sections at the ends of the two arrays, as we did in the branches above
        NSMutableArray<SGListSection *> *beforeTransitionToSections = beforeTransition.fromSections.mutableCopy;
        [beforeTransitionToSections addObjectsFromArray:sectionsToInsertBefore];
        NSMutableArray<SGListSection *> *afterTransitionFromSections = afterTransition.toSections.mutableCopy;
        [afterTransitionFromSections addObjectsFromArray:sectionsToInsertAfter];

        // Here's the special part for the before AND after case: we repeatedly try to move the sections we've added
        // to the right places, iterating until we converge.
        NSInteger safetyCounter = 0;
        while (YES) {
            BOOL reorderedBefore = [self.class moveSections:sectionsToInsertBefore inArray:beforeTransitionToSections toMatchArray:afterTransitionFromSections];
            BOOL reorderedAfter = [self.class moveSections:sectionsToInsertAfter inArray:afterTransitionFromSections toMatchArray:beforeTransitionToSections];

            if (!reorderedBefore && !reorderedAfter) {
                // We've converged on correct positions for all the inserted empty sections
                break;
            }
            if (++safetyCounter > 10) {
                NSLog(@"SGListTransition -extractInsertDeleteSectionOperationsToNewTransitions was unable to synchronize to/from sections for middle transition.");
                break;
            }
        }

        // Set up all the states
        beforeTransition.toSections = beforeTransitionToSections;
        self.fromSections = beforeTransition.toSections;
        afterTransition.fromSections = afterTransitionFromSections;
        self.toSections = afterTransition.fromSections;
    }

    // Build return array, and recompute operations
    BOOL didRecomputeOurOperations = NO;
    NSMutableArray<SGListTransition *> *transitions = [NSMutableArray new];
    if (beforeTransition) {
        // TODO: we can actually set the one operation array that it needs directly here: insertSectionsInNew
        [beforeTransition computeOperations];
        [transitions addObject:beforeTransition];
    }
    if (beforeTransition || afterTransition) {
        [self computeOperations];
        didRecomputeOurOperations = YES;
    }
    [transitions addObject:self];
    if (afterTransition) {
        // TODO: we can actually set the one operation array that it needs directly here: deleteSectionsInOld
        [afterTransition computeOperations];
        [transitions addObject:afterTransition];
    }

    // Need to regenerate our inter-section moves
    if (hadMoves && didRecomputeOurOperations) {
        // When we re-invoked -computeOperations above, our moves went back to being delete/insert pairs,
        // so we convert them again.
        [self convertInsertDeletePairsToInterSectionMoves];
    }

    return transitions;
}

#pragma mark - Informational

- (BOOL)hasDifferences {
    return self.reloadSectionsInOld.count > 0 ||
        self.deleteSectionsInOld.count > 0 ||
        self.deleteItemsInOld.count > 0 ||
        self.insertSectionsInNew.count > 0 ||
        self.insertItemsInNew.count > 0 ||
        self.sectionMoveTuples.count > 0 ||
        self.intraSectionMoveTuples.count > 0 ||
        self.interSectionMoveTuples.count > 0;
}

- (BOOL)hasOperationsOtherThanSectionMoves {
    return self.reloadSectionsInOld.count > 0 ||
    self.deleteSectionsInOld.count > 0 ||
    self.deleteItemsInOld.count > 0 ||
    self.insertSectionsInNew.count > 0 ||
    self.insertItemsInNew.count > 0 ||
    self.intraSectionMoveTuples.count > 0 ||
    self.interSectionMoveTuples.count > 0;
}


- (BOOL)isAnimatable {
    return self.reloadSectionsInOld &&
        self.deleteSectionsInOld &&
        self.deleteItemsInOld &&
        self.insertSectionsInNew &&
        self.insertItemsInNew &&
        self.sectionMoveTuples &&
        self.intraSectionMoveTuples &&
        self.interSectionMoveTuples;
}

- (SGListTransitionCounts)counts {
    SGListTransitionCounts counts = (SGListTransitionCounts) {
        .countItemsReloaded = 0,
        .countItemsDeleted = 0,
        .countItemsInserted = 0
    };

    if (self.isAnimatable) {
        {
            NSInteger oldSectionIndex = self.reloadSectionsInOld.firstIndex;
            while(oldSectionIndex != NSNotFound) {
                counts.countItemsReloaded += self.fromSections[oldSectionIndex].items.count;
                oldSectionIndex = [self.reloadSectionsInOld indexGreaterThanIndex:oldSectionIndex];
            }
        }

        {
            NSInteger oldSectionIndex = self.deleteSectionsInOld.firstIndex;
            while(oldSectionIndex != NSNotFound) {
                counts.countItemsDeleted += self.fromSections[oldSectionIndex].items.count;
                oldSectionIndex = [self.deleteSectionsInOld indexGreaterThanIndex:oldSectionIndex];
            }
            counts.countItemsDeleted += self.deleteItemsInOld.count;
        }

        {
            NSInteger newSectionIndex = self.insertSectionsInNew.firstIndex;
            while(newSectionIndex != NSNotFound) {
                counts.countItemsInserted += self.toSections[newSectionIndex].items.count;
                newSectionIndex = [self.insertSectionsInNew indexGreaterThanIndex:newSectionIndex];
            }
            counts.countItemsInserted += self.insertItemsInNew.count;
        }
    }

    return counts;
}

#pragma mark - Perform animations

- (BOOL)applyToTableView:(UITableView *)tableView {
    if (self.isAnimatable) {
        // Figure out animation styles. We normally use Top, but to avoid busy looking animations, we drop back
        // to Fade for deletes in the presence of similar numbers of inserts.
        SGListTransitionCounts counts = [self counts];
        UITableViewRowAnimation reloadAnimation = UITableViewRowAnimationFade;
        UITableViewRowAnimation deleteAnimation = (counts.countItemsInserted < 0.25 * counts.countItemsDeleted) ? UITableViewRowAnimationTop : UITableViewRowAnimationFade;
        UITableViewRowAnimation insertAnimation = UITableViewRowAnimationTop;

        // Update table view state
        // Note that iOS will apply our deletions before our insertions regardless of the order that we have
        // here. The section indices and row/item index paths are in terms of the old state
        // of the table for reloads and deletions, but in terms of the new state of the table for insertions.
        //
        // See Apple's documentation at
        // https://developer.apple.com/library/ios/documentation/UserExperience/Conceptual/TableView_iPhone/ManageInsertDeleteRow/ManageInsertDeleteRow.html

        [tableView beginUpdates];
        if (self.reloadSectionsInOld.count > 0) {
            [tableView reloadSections:self.reloadSectionsInOld withRowAnimation:reloadAnimation];
        }
        if (self.deleteSectionsInOld.count > 0) {
            [tableView deleteSections:self.deleteSectionsInOld withRowAnimation:deleteAnimation];
        }
        if (self.deleteItemsInOld.count > 0) {
            [tableView deleteRowsAtIndexPaths:self.deleteItemsInOld withRowAnimation:deleteAnimation];
        }
        if (self.insertSectionsInNew.count > 0) {
            [tableView insertSections:self.insertSectionsInNew withRowAnimation:insertAnimation];
        }
        if (self.insertItemsInNew.count > 0) {
            [tableView insertRowsAtIndexPaths:self.insertItemsInNew withRowAnimation:insertAnimation];
        }
        for (SGIndexTuple *indexTuple in self.sectionMoveTuples) {
            [tableView moveSection:indexTuple.indexInOld toSection:indexTuple.indexInNew];
        }
        for (SGIndexPathTuple *indexPathTuple in self.intraSectionMoveTuples) {
            [tableView moveRowAtIndexPath:indexPathTuple.indexPathInOld toIndexPath:indexPathTuple.indexPathInNew];
        }
        for (SGIndexPathTuple *indexPathTuple in self.interSectionMoveTuples) {
            [tableView moveRowAtIndexPath:indexPathTuple.indexPathInOld toIndexPath:indexPathTuple.indexPathInNew];
        }
        [tableView endUpdates];

        return YES;
    } else {
        [tableView reloadData];
        return NO;
    }
}

- (BOOL)applyToCollectionView:(UICollectionView *)collectionView {
    if (self.isAnimatable) {
        [collectionView performBatchUpdates:^{
            if (self.reloadSectionsInOld.count > 0) {
                [collectionView reloadSections:self.reloadSectionsInOld];
            }
            if (self.deleteSectionsInOld.count > 0) {
                [collectionView deleteSections:self.deleteSectionsInOld];
            }
            if (self.deleteItemsInOld.count > 0) {
                [collectionView deleteItemsAtIndexPaths:self.deleteItemsInOld];
            }
            if (self.insertSectionsInNew.count > 0) {
                [collectionView insertSections:self.insertSectionsInNew];
            }
            if (self.insertItemsInNew.count > 0) {
                [collectionView insertItemsAtIndexPaths:self.insertItemsInNew];
            }
            for (SGIndexTuple *indexTuple in self.sectionMoveTuples) {
                [collectionView moveSection:indexTuple.indexInOld toSection:indexTuple.indexInNew];
            }
            for (SGIndexPathTuple *indexPathTuple in self.intraSectionMoveTuples) {
                [collectionView moveItemAtIndexPath:indexPathTuple.indexPathInOld toIndexPath:indexPathTuple.indexPathInNew];
            }
            for (SGIndexPathTuple *indexPathTuple in self.interSectionMoveTuples) {
                [collectionView moveItemAtIndexPath:indexPathTuple.indexPathInOld toIndexPath:indexPathTuple.indexPathInNew];
            }
        } completion:nil];

        return YES;
    } else {
        [collectionView reloadData];
        return NO;
    }
}

#pragma mark - NSObject

- (NSString *)description {
    // This format and ordering is expected by SGListAnimatorTests.

    if (self.isAnimatable) {
        NSMutableArray<NSString *> *pieces = [NSMutableArray new];
        if (self.reloadSectionsInOld.count > 0) {
            [pieces addObject:[self descriptionPieceForOperation:@"S*" indexSet:self.reloadSectionsInOld]];
        }
        if (self.deleteSectionsInOld.count > 0) {
            [pieces addObject:[self descriptionPieceForOperation:@"S-" indexSet:self.deleteSectionsInOld]];
        }
        if (self.deleteItemsInOld.count > 0) {
            [pieces addObject:[self descriptionPieceForOperation:@"I-" indexPaths:self.deleteItemsInOld]];
        }
        if (self.insertSectionsInNew.count > 0) {
            [pieces addObject:[self descriptionPieceForOperation:@"S+" indexSet:self.insertSectionsInNew]];
        }
        if (self.insertItemsInNew.count > 0) {
            [pieces addObject:[self descriptionPieceForOperation:@"I+" indexPaths:self.insertItemsInNew]];
        }
        if (self.sectionMoveTuples.count > 0) {
            [pieces addObject:[self descriptionPieceForOperation:@"S>" indexTuples:self.sectionMoveTuples]];
        }
        if (self.intraSectionMoveTuples.count > 0) {
            [pieces addObject:[self descriptionPieceForOperation:@"I<" indexPathTuples:self.intraSectionMoveTuples]];
        }
        if (self.interSectionMoveTuples.count > 0) {
            [pieces addObject:[self descriptionPieceForOperation:@"I>" indexPathTuples:self.interSectionMoveTuples]];
        }
        return [pieces componentsJoinedByString:@";"];
    } else {
        return @"*";
    }
}

#pragma mark - Private description related

- (NSString *)descriptionPieceForOperation:(NSString *)operationString indexSet:(NSIndexSet *)indexSet {
    NSMutableArray<NSString *> *indexStrings = [NSMutableArray new];
    NSInteger index = indexSet.firstIndex;
    while (index != NSNotFound) {
        [indexStrings addObject:[NSString stringWithFormat:@"%li", (long)index]];
        index = [indexSet indexGreaterThanIndex:index];
    }

    NSString *indicesString = [indexStrings componentsJoinedByString:@","];
    return [NSString stringWithFormat:@"%@%@",operationString, indicesString];
}

- (NSString *)descriptionPieceForOperation:(NSString *)operationString indexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    NSMutableArray<NSString *> *indexPathStrings = [NSMutableArray new];
    for (NSIndexPath *indexPath in [self sortedIndexPaths:indexPaths]) {
        [indexPathStrings addObject:[NSString stringWithFormat:@"%li.%li", (long)indexPath.section, (long)indexPath.item]];
    }

    NSString *indexPathsString = [indexPathStrings componentsJoinedByString:@","];
    return [NSString stringWithFormat:@"%@%@",operationString, indexPathsString];
}

- (NSString *)descriptionPieceForOperation:(NSString *)operationString indexTuples:(NSArray<SGIndexTuple *> *)indexTuples {
    NSMutableArray<NSString *> *tupleStrings = [NSMutableArray new];
    for (SGIndexTuple *indexTuple in [self sortedIndexTuples:indexTuples]) {
        [tupleStrings addObject:indexTuple.description];
    }

    NSString *tupleString = [tupleStrings componentsJoinedByString:@","];
    return [NSString stringWithFormat:@"%@%@",operationString, tupleString];
}

- (NSString *)descriptionPieceForOperation:(NSString *)operationString indexPathTuples:(NSArray<SGIndexPathTuple *> *)indexPathTuples {
    NSMutableArray<NSString *> *tupleStrings = [NSMutableArray new];
    for (SGIndexPathTuple *indexPathTuple in [self sortedIndexPathTuples:indexPathTuples]) {
        [tupleStrings addObject:indexPathTuple.description];
    }

    NSString *tupleString = [tupleStrings componentsJoinedByString:@","];
    return [NSString stringWithFormat:@"%@%@",operationString, tupleString];
}

#pragma mark - Sorting helpers

// These are used to keep our descriptions in a consistent and easy to write order
// for the convenience of unit testing code only.

- (NSArray<NSIndexPath *> *)sortedIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    NSSortDescriptor *sectionSort = [[NSSortDescriptor alloc] initWithKey:@"section" ascending:YES];
    NSSortDescriptor *rowSort = [[NSSortDescriptor alloc]initWithKey:@"row" ascending:YES];
    return [indexPaths sortedArrayUsingDescriptors:@[ sectionSort, rowSort ]];
}

- (NSArray<SGIndexTuple *> *)sortedIndexTuples:(NSArray<SGIndexTuple *> *)indexTuples {
    NSSortDescriptor *indexInOldSort = [[NSSortDescriptor alloc] initWithKey:@"indexInOld" ascending:YES];
    return [indexTuples sortedArrayUsingDescriptors:@[ indexInOldSort ]];
}

- (NSArray<SGIndexPathTuple *> *)sortedIndexPathTuples:(NSArray<SGIndexPathTuple *> *)indexPathTuples {
    NSSortDescriptor *sectionSort = [[NSSortDescriptor alloc] initWithKey:@"indexPathInOld.section" ascending:YES];
    NSSortDescriptor *rowSort = [[NSSortDescriptor alloc]initWithKey:@"indexPathInOld.row" ascending:YES];
    return [indexPathTuples sortedArrayUsingDescriptors:@[ sectionSort, rowSort]];
}

#pragma mark - Shared helpers

+ (NSArray *)inArray:(NSArray *)inArray replaceObject:(id)object withObjects:(NSArray *)replacementArray {
    NSMutableArray *mutableInArray = [inArray mutableCopy];
    NSInteger index = [mutableInArray indexOfObject:object];
    NSAssert(index != NSNotFound, @"Expected inArray to contain object provided.");
    [mutableInArray replaceObjectsInRange:NSMakeRange(index, 1) withObjectsFromArray:replacementArray];
    return [mutableInArray copy];
}

#pragma mark - Private helpers

+ (NSIndexSet *)indexSetForIndices:(NSArray<NSNumber *> *)indices {
    NSMutableIndexSet *indexSet = [NSMutableIndexSet new];
    for (NSNumber *index in indices) {
        [indexSet addIndex:index.integerValue];
    }
    return indexSet;
}

+ (NSArray<NSNumber *> *)indicesForIndexSet:(NSIndexSet *)indexSet {
    NSMutableArray<NSNumber *> *indices = [NSMutableArray new];
    NSInteger indexFromSet = indexSet.firstIndex;
    while (indexFromSet != NSNotFound) {
        [indices addObject:@(indexFromSet)];

        indexFromSet = [indexSet indexGreaterThanIndex:indexFromSet];
    }
    return indices;
}

+ (BOOL)moveSections:(NSArray<SGListSection *> *)sectionsToMove inArray:(NSMutableArray<SGListSection *> *)array toMatchArray:(NSArray<SGListSection *> *)referenceArray {
    NSArray *originalArray = [array copy];

    NSMutableArray<SGSectionAndIndexTuple *> *movesToDo = [NSMutableArray new];
    for (SGListSection *section in sectionsToMove) {
        [array removeObject:section];
        SGSectionAndIndexTuple *tuple = [SGSectionAndIndexTuple new];
        tuple.section = section;
        tuple.index = [self indexOfSectionWithIdentifier:section.identifier inArray:referenceArray];
        [movesToDo addObject:tuple];
    }

    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
    NSArray<SGSectionAndIndexTuple *> *sortedMovesToDo = [movesToDo sortedArrayUsingDescriptors:@[ sortDescriptor ]];
    for (SGSectionAndIndexTuple *tuple in sortedMovesToDo) {
        [array insertObject:tuple.section atIndex:tuple.index];
    }

    return ![array isEqualToArray:originalArray];
}

+ (NSInteger)indexOfSectionWithIdentifier:(id)identifier inArray:(NSArray<SGListSection *> *)array {
    for (NSInteger i = 0; i < array.count; ++i) {
        if ([array[i].identifier isEqual:identifier]) {
            return i;
        }
    }
    return NSNotFound;
}

@end
