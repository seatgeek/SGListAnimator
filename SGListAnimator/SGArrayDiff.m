//
//  SGArrayDiff.m
//  SeatGeek
//
//  Created by David McNerney on 12/22/15.
//  Copyright © 2015 SeatGeek. All rights reserved.
//

#import "SGArrayDiff.h"
#import "SGIndexTuple.h"

@implementation SGArrayDiff

#pragma mark - Public

+ (SGArrayDiff *)diffFromArray:(NSArray *)oldArray toArray:(NSArray *)newArray doMoves:(BOOL)doMoves includeUnchanged:(BOOL)includeUnchanged {

    SGArrayDiff *arrayDiff = [SGArrayDiff new];

    // We can't handle duplicates, so return if there are any in either the old or new
    NSSet *oldSet = [NSSet setWithArray:oldArray];
    NSSet *newSet = [NSSet setWithArray:newArray];
    if (oldSet.count != oldArray.count ||
        newSet.count != newArray.count) {

        return nil;
    }

    // Add deletions
    NSMutableArray<NSNumber *> *deleteInOld = [NSMutableArray array];
    for (NSInteger oldIndex = 0; oldIndex < oldArray.count; ++oldIndex) {
        if (![newSet containsObject:oldArray[oldIndex]]) {
            [deleteInOld addObject:@(oldIndex)];
        }
    }
    arrayDiff.deleteInOld = deleteInOld;

    // Add insertions
    NSMutableArray<NSNumber *> *insertInNew = [NSMutableArray array];
    for (NSInteger newIndex = 0; newIndex < newArray.count; ++newIndex) {
        if (![oldSet containsObject:newArray[newIndex]]) {
            [insertInNew addObject:@(newIndex)];
        }
    }
    arrayDiff.insertInNew = insertInNew;

    // Catalog unchanged and check for rearrangement.

    NSMutableSet *unionSet = [NSMutableSet setWithSet:oldSet];
    [unionSet intersectSet:newSet];

    NSMutableArray *unchangedObjectsInOld = [NSMutableArray array];
    NSMutableArray<NSNumber *> *unchangedIndicesInOld = [NSMutableArray array];
    for (NSInteger oldIndex = 0; oldIndex < oldArray.count; ++oldIndex) {
        if ([unionSet containsObject:oldArray[oldIndex]]) {
            [unchangedObjectsInOld addObject:oldArray[oldIndex]];
            [unchangedIndicesInOld addObject:@(oldIndex)];
        }
    }

    NSMutableArray *unchangedObjectsInNew = [NSMutableArray array];
    NSMutableArray<NSNumber *> *unchangedIndicesInNew = [NSMutableArray array];
    for (NSInteger newIndex = 0; newIndex < newArray.count; ++newIndex) {
        if ([unionSet containsObject:newArray[newIndex]]) {
            [unchangedObjectsInNew addObject:newArray[newIndex]];
            [unchangedIndicesInNew addObject:@(newIndex)];
        }
    }

    // Add moved and unchanged, as required
    if (![unchangedObjectsInOld isEqual:unchangedObjectsInNew]) {
        // Items have moved, so if we aren't to support moves, then we cannot determine a diff.
        if (!doMoves) {
            return nil;
        }

        // This algorithm produces unnecessary moves, for example: "01234" -> "40123" is ">0/1,1/2,2/3,3/4,4/0",
        // when really UITableView and UICollectionView just need to be told ">4/0". If this causes
        // performance problems, the algo might need to be improved, but a smarter solution seems
        // very much non-trivial.
        NSMutableArray<SGIndexTuple *> *moved = [NSMutableArray new];
        NSMutableArray<SGIndexTuple *> *unchanged = [NSMutableArray new];
        for (NSInteger i = 0; i < unchangedObjectsInOld.count; ++i) {
            id item = unchangedObjectsInOld[i];
            NSInteger j = [unchangedObjectsInNew indexOfObject:item];
            NSInteger oldIndex = unchangedIndicesInOld[i].integerValue;
            NSInteger newIndex = unchangedIndicesInNew[j].integerValue;
            SGIndexTuple *indexTuple = [SGIndexTuple withOld:oldIndex new:newIndex];
            if (j != i) {
                // moved
                [moved addObject:indexTuple];
            } else if (includeUnchanged) {
                // not moved
                [unchanged addObject:indexTuple];
            }
        }
        arrayDiff.moved = moved;
        arrayDiff.unchanged = unchanged;
    } else {
        arrayDiff.moved = @[];

        if (includeUnchanged) {
            NSMutableArray<SGIndexTuple *> *unchanged = [NSMutableArray new];
            for (NSInteger i = 0; i < unchangedIndicesInOld.count; ++i) {
                SGIndexTuple *indexTuple = [SGIndexTuple withOld:unchangedIndicesInOld[i].integerValue new:unchangedIndicesInNew[i].integerValue];
                [unchanged addObject:indexTuple];
            }
            arrayDiff.unchanged = unchanged;
        } else {
            arrayDiff.unchanged = @[];
        }
    }

    return arrayDiff;
}

#pragma mark - NSObject

- (NSString *)description {
    // This format and ordering is expected by SGListAnimatorTests.

    NSMutableArray<NSString *> *pieces = [NSMutableArray new];
    if (self.unchanged.count > 0) {
        NSMutableArray<NSNumber *> *unchangedInOld = [NSMutableArray new];
        for (SGIndexTuple *indexTuple in self.unchanged) {
            [unchangedInOld addObject:@(indexTuple.indexInOld)];
        }
        [pieces addObject:[self descriptionPieceForOperation:@"=" indices:unchangedInOld]];
    }
    if (self.deleteInOld.count > 0) {
        [pieces addObject:[self descriptionPieceForOperation:@"-" indices:self.deleteInOld]];
    }
    if (self.insertInNew.count > 0) {
        [pieces addObject:[self descriptionPieceForOperation:@"+" indices:self.insertInNew]];
    }
    if (self.moved.count > 0) {
        [pieces addObject:[self descriptionPieceForOperation:@">" indexTuples:self.moved]];
    }
    return [pieces componentsJoinedByString:@";"];
}

- (NSString *)descriptionPieceForOperation:(NSString *)operationString indices:(NSArray<NSNumber *> *)indices {
    NSString *indicesString = [indices componentsJoinedByString:@","];
    return [NSString stringWithFormat:@"%@%@",operationString, indicesString];
}

- (NSString *)descriptionPieceForOperation:(NSString *)operationString indexTuples:(NSArray<SGIndexTuple *> *)indexTuples {
    NSString *indexTuplesString = [indexTuples componentsJoinedByString:@","];
    return [NSString stringWithFormat:@"%@%@",operationString, indexTuplesString];
}

@end
