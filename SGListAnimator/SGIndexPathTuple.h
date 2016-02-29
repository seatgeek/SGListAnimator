//
//  SGIndexPathTuple.h
//  SeatGeek
//
//  Created by David McNerney on 1/4/16.
//  Copyright © 2016 SeatGeek. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * Convenience object holding two index paths.
 * Used to track moves.
 */
@interface SGIndexPathTuple : NSObject

+ (instancetype)withOld:(NSIndexPath *)oldIndexPath new:(NSIndexPath *)newIndexPath;

@property (nonatomic, readonly) NSIndexPath *indexPathInOld;
@property (nonatomic, readonly) NSIndexPath *indexPathInNew;

@end
