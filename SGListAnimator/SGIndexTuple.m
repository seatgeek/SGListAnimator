//
//  SGIndexTuple.m
//  SeatGeek
//
//  Created by David McNerney on 1/16/16.
//  Copyright © 2016 SeatGeek. All rights reserved.
//

#import "SGIndexTuple.h"

@implementation SGIndexTuple

+ (instancetype)withOld:(NSInteger)oldIndex new:(NSInteger)newIndex {
    SGIndexTuple *tuple = [self new];
    tuple->_indexInOld = oldIndex;
    tuple->_indexInNew = newIndex;
    return tuple;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%li/%li",
        (long)self.indexInOld,
        (long)self.indexInNew
    ];
}

@end
