//
//  SGIndexTuple.h
//  SeatGeek
//
//  Created by David McNerney on 1/16/16.
//  Copyright © 2016 SeatGeek. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SGIndexTuple : NSObject

+ (instancetype)withOld:(NSInteger)oldIndex new:(NSInteger)newIndex;

@property (nonatomic, readonly) NSInteger indexInOld;
@property (nonatomic, readonly) NSInteger indexInNew;

@end
