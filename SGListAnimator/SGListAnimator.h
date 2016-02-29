//
//  SGListAnimator.h
//  SeatGeek
//
//  Created by David McNerney on 12/21/15.
//  Copyright © 2015 SeatGeek. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SGListSection;
#import "SGListTransition.h"

/**
 * This class provides animated transitions for your table and colletion views
 * It assumes that section titles are unique, and that item objects (the model
 * objects that correspond to table view rows or collection view items) are
 * suitable for inclusion in a NSSet. This just means they should implement
 * -hash and -isEqual appropriately.
 *
 * You can use one of the convenience class methods with your own backing arrays,
 * or create a SGListAnimator object that manages your backing data for you, invoking
 * -transitionTableViewToSections: on it whenever you have updated backing data. The latter
 * approach is required to enable support for any of the various types of animated moves;
 * see those properties below.
 */
@interface SGListAnimator : NSObject

#pragma mark - Convenience class methods

/**
 * Given a table view backed by a section array, whose last rendered state
 * was described in oldSections, and whose data source now provides state
 * matching newSections, animate to the new state.
 *
 * Returns: YES if an animated transition done or no transition needed,
 *          NO if -reloadData was invoked on the table view.
 */
+ (BOOL)transitionTableView:(nonnull UITableView *)tableView
               fromSections:(nullable NSArray<SGListSection *> *)oldSections
                 toSections:(nonnull NSArray<SGListSection *> *)newSections;

/**
 * Exactly like the above, but for client code that doesn't want to use SGListSection objects.
 */
+ (BOOL)transitionTableView:(nonnull UITableView *)tableView
           fromSectionItems:(nullable NSArray<NSArray *> *)oldSectionItems
                     titles:(nullable NSArray<NSString *> *)oldTitles
             toSectionItems:(nonnull NSArray<NSArray *> *)newSectionItems
                     titles:(nonnull NSArray<NSString *> *)newTitles;

/**
 * Like the corresponding above table view method, but used for collection views.
 */
+ (BOOL)transitionCollectionView:(nonnull UICollectionView *)collectionView
                    fromSections:(nullable NSArray<SGListSection *> *)oldSections
                      toSections:(nonnull NSArray<SGListSection *> *)newSections;

/**
 * Like the corresponding above table view method, but used for collection views.
 */
+ (BOOL)transitionCollectionView:(nonnull UICollectionView *)collectionView
                fromSectionItems:(nullable NSArray<NSArray *> *)oldSectionItems
                          titles:(nullable NSArray<NSString *> *)oldTitles
                  toSectionItems:(nonnull NSArray<NSArray *> *)newSectionItems
                          titles:(nonnull NSArray<NSString *> *)newTitles;

#pragma mark - Properties

// You can work with a SGListAnimator object using the interface below,
// rather than using the convenience class methods above. Note that when you use a list
// animator object, it holds your backing data. Steps:
//     - Create a SGListAnimator
//     - Assign your table or collection view to the appropriate property below.
//     - Use your list animator's -currentSections array in all your data source methods.
//     - Use -transitionTableViewToSections: or -transitionCollectionViewToSections: each
//       time you have updated backing data.

/// Required when working with a table view
@property (nonatomic, nullable) UITableView *tableView;

/// Required when working with a collection view
@property (nonatomic, nullable) UICollectionView *collectionView;

/**
 * The current backing data for your table/collection view. Data source methods must use this.
 * Normally you don't need to set this; it gets set when you invoke -transitionTableViewToSections:.
 */
@property (nonatomic, nullable) NSArray<SGListSection *> *currentSections;

/**
 * This property controls our behavior when the sections move around. If YES,
 * they are animated as proper moves. If NO (the default), the table view is reloaded. Setting
 * this to YES causes additional work to be done which could be significant if you
 * have a great many sections, but for the vast majority of use cases is fine.
 */
@property (nonatomic) BOOL doSectionMoves;

/**
 * This property controls our behavior when items move within a section. If YES,
 * they are animated as proper moves. If NO (the default), the section is reloaded.
 * Setting this to YES causes additional work to be done which could be significant
 * if you have a large number of items in a section and a move occurs.
 */
@property (nonatomic) BOOL doIntraSectionMoves;

/**
 * This property controls our behavior when items move between sections. If YES,
 * they are animated as proper moves. If NO (the default), they are animated
 * as a delete from the old section and an insert into the new section. Setting
 * this to YES causes some additional work to be done to identify the moves,
 * and to separate out insert/delete section operations into separate transitions
 * to avoid upsetting UITableView.
 */
@property (nonatomic) BOOL doInterSectionMoves;

/**
 * This optional block gives you an opportunity to forgo animating a transition,
 * causing the SGListAnimator to just call -reloadData instead. Here's code that
 * we use for a table view used to show autocomplete results as the user types:
 *
 *     // For transitions involving lots of inserts and deletes, or equal numbers of inserts and deletes,
 *     // animated transitions can look busy and distracting.
 *     _tableViewAnimator.shouldAnimateTransitionsBlock = ^(NSArray<SGListTransition *> *transitions) {
 *         SGListTransitionCounts counts = [SGListAnimator totalCountsForTransitions:transitions];
 *         if ((counts.countItemsInserted > 0 && counts.countItemsDeleted == counts.countItemsInserted) ||
 *             (counts.countItemsInserted > 3 && counts.countItemsDeleted > 3)) {
 *
 *             return NO;
 *         } else {
 *             return YES;
 *         }
 *     };
 *
 */
@property (nonatomic, copy, nullable) BOOL (^shouldAnimateTransitionsBlock)(NSArray<SGListTransition *> * __nonnull transitions);

#pragma mark - Transition methods

/**
 * Transitions the table view from self.currentSections to newSections. This method
 * powers the class convenience methods above.
 *
 * Returns: YES if an animated transition done or no transition needed,
 *          NO if -reloadData was invoked on the table view
 */
- (BOOL)transitionTableViewToSections:(nonnull NSArray<SGListSection *> *)newSections;

/**
 * Like the above table view method, but used for collection views.
 */
- (BOOL)transitionCollectionViewToSections:(nonnull NSArray<SGListSection *> *)newSections;

#pragma mark - Utility & misc

/**
 * Provides statistics about the set of transitions that is passed to it. Normally only used
 * by code in shouldAnimateTransitionsBlock.
 */
+ (SGListTransitionCounts)totalCountsForTransitions:(nonnull NSArray<SGListTransition *> *)transitions;

@end
