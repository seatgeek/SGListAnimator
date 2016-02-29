//
//  SGListTransition.h
//  SeatGeek
//
//  Created by David McNerney on 12/22/15.
//  Copyright © 2015 SeatGeek. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SGListSection, SGArrayDiff, SGIndexTuple, SGIndexPathTuple;


typedef struct SGListTransitionCounts {
    NSInteger countItemsReloaded;
    NSInteger countItemsDeleted;
    NSInteger countItemsInserted;
} SGListTransitionCounts;


/**
 * Used by SGListAnimator internally to represent a transition of a table
 * or collection view from one state to another. Defined
 * by a before state (fromSections), and after state (toSections), and
 * the operations that are required to go from before to after. Normally,
 * client code sets fromSections and toSections, then invokes -computeOperations
 * to fill in the operations.
 *
 * Our operations correspond to the method calls that will need to be made on the table
 * or collection view to take it to its new state. Section indices and index paths are
 * valid in either the old or the new state, as indicated by the property name.
 */
@interface SGListTransition : NSObject

#pragma mark - Configuration

/**
 * Allow moves of sections? Defaults to NO, which means the table view is reloaded
 * if such moves are encountered.
 */
@property (nonatomic) BOOL doSectionMoves;

/**
 * Allow moves inside sections? Defaults to NO, which means the section is reloaded
 * if such moves are encountered.
 */
@property (nonatomic) BOOL doIntraSectionMoves;

#pragma mark - Before and after

@property (nonatomic, copy) NSArray<SGListSection *> *fromSections;
@property (nonatomic, copy) NSArray<SGListSection *> *toSections;

#pragma mark - Operations

@property (nonatomic, copy) NSIndexSet *reloadSectionsInOld;

@property (nonatomic, copy) NSIndexSet *deleteSectionsInOld;
@property (nonatomic, copy) NSArray<NSIndexPath *> *deleteItemsInOld;

@property (nonatomic, copy) NSIndexSet *insertSectionsInNew;
@property (nonatomic, copy) NSArray<NSIndexPath *> *insertItemsInNew;

@property (nonatomic, copy) NSArray<SGIndexTuple *> *sectionMoveTuples;
@property (nonatomic, copy) NSArray<SGIndexPathTuple *> *intraSectionMoveTuples;
@property (nonatomic, copy) NSArray<SGIndexPathTuple *> *interSectionMoveTuples;

#pragma mark - Computing

/**
 * Compares toSections to fromSections, and updates the operations properties
 * above so that they describe the difference between the two states.
 *
 * Moves of sections and moves of items inside sections are handled per
 * the -doSectionMoves and -doIntraSectionMoves properties.
 *
 * By default, handles moves of items between sections as delete/insert operations,
 * but the methods below can be used to convert those delete/insert pairs to moves.
 */
- (void)computeOperations;

#pragma mark - Extracting transitions & converting operations

//TODO: comment
- (NSArray<SGListTransition *> *)extractMoveSectionOperationsToBeforeTransition;

/**
 * Converts delete/insert of same item in different sections to moves. After using
 * this method, you'll need to use the below method to separate any insert and delete
 * section operations to their own transitions, since UITableView cannot handle moves
 * to new sections or from deleted sections in one single transition.
 */
- (void)convertInsertDeletePairsToInterSectionMoves;

/**
 * If any insert or delete section operations are present, modifies this object and
 * creates additional before or after transitions to separate them from this transition.
 *
 * Returns an array of all the transitions -- if no insert/delete section operations
 * present, this will be just a 1 item array containing the original transition.
 */
- (NSArray<SGListTransition *> *)extractInsertDeleteSectionOperationsToNewTransitions;

#pragma mark - Informational

/** This will return NO if the old and new sections are the same, so that we contain only empty operations. */
- (BOOL)hasDifferences;

/** Returns YES if there are any operations present other than section move operations */
- (BOOL)hasOperationsOtherThanSectionMoves;

/**
 * This will return NO when we aren't able to animate a transition. In that case, -applyToTableView: will just
 * have to reload the table view. Currently, this happens if existing sections are rearranged, or if no operations
 * were ever set in the SGListTransition.
 */
- (BOOL)isAnimatable;

/** Computes some statistics about the operations we hold. */
- (SGListTransitionCounts)counts;

#pragma mark - Perform animations

/**
 * Performs the animations specified by our operations on the table view.
 *
 * Returns: YES if was able to animate, or nothing to animate
 *          NO if unable to animate, so reloaded the table view
 */
- (BOOL)applyToTableView:(UITableView *)tableView;

/**
 * Just like the above, but for collection views.
 */
- (BOOL)applyToCollectionView:(UICollectionView *)collectionView;

#pragma mark - Shared helpers

+ (NSArray *)inArray:(NSArray *)inArray replaceObject:(id)object withObjects:(NSArray *)replacementArray;

#pragma mark - Exposed for unit tests

/**
 * Moves the sections identified around in the first array so that they are positioned
 * at the same indices as the sections with the same identifier in the second array.
 * The two arrays must be the same size, and the sections in each array must have the same
 * identifiers. They won't normally be the same objects, and they may not return true
 * from -isEqual due to having different items, but there must be a one to one correspondence
 * of identifiers.
 *
 * Returns true if moves were made, false if no changes were needed
 */
+ (BOOL)moveSections:(NSArray<SGListSection *> *)sectionsToMove inArray:(NSMutableArray<SGListSection *> *)array toMatchArray:(NSArray<SGListSection *> *)referenceArray;

@end
