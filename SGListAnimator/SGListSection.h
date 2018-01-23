//
//  SGListSection.h
//  SeatGeek
//
//  Created by David McNerney on 12/21/15.
//  Copyright © 2015 SeatGeek. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * These objects model sections in a table view or collection view. The items
 * property and one of title/identifier should be set.
 */
@interface SGListSection : NSObject <NSCopying> 

/** Convenience */

/// Create a section with a section title and content
+ (nonnull instancetype)sectionWithTitle:(nonnull NSString *)title items:(nonnull NSArray *)items;

/// Create a section with content but no section title
+ (nonnull instancetype)sectionWithIdentifier:(nonnull NSString *)identifier items:(nonnull NSArray *)items;

/**
 * Section title -- this is normally a convenient way to identify your sections. Each
 * section must have a unique title.
 */
@property (nonatomic, nullable) NSString *title;

/**
 * Identifier for the section -- this can be any object that implements
 * -hash and -isEqual to uniquely identify one of your sections. Use this property
 * instead of title if you have model objects that you want to use to represent
 * your sections. The title property actually stores its string here.
 */
@property (nonatomic, nullable) id identifier;


/** The model objects corresponding the table view rows or collection view items */
@property (nonatomic, nullable) NSArray *items;

@end
