//
//  SGIndexPathTuple.m
//  SeatGeek
//
//  Created by David McNerney on 1/4/16.
//  Copyright © 2016 SeatGeek. All rights reserved.
//

#import "SGIndexPathTuple.h"

@implementation SGIndexPathTuple

+ (instancetype)withOld:(NSIndexPath *)oldIndexPath new:(NSIndexPath *)newIndexPath {
    SGIndexPathTuple *tuple = [self new];
    tuple->_indexPathInOld = oldIndexPath;
    tuple->_indexPathInNew = newIndexPath;
    return tuple;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%li.%li/%li.%li",
        (long)self.indexPathInOld.section,
        (long)self.indexPathInOld.item,
        (long)self.indexPathInNew.section,
        (long)self.indexPathInNew.item
    ];
}

@end
