//
//  SGListSection.m
//  SeatGeek
//
//  Created by David McNerney on 12/21/15.
//  Copyright © 2015 SeatGeek. All rights reserved.
//

#import "SGListSection.h"

@implementation SGListSection

#pragma mark - Initialization

+ (instancetype)sectionWithTitle:(NSString *)title items:(NSArray *)items {
    SGListSection *section = [self new];
    section.title = title;
    section.items = items;
    return section;
}

#pragma mark - Public

- (NSString *)title {
    NSAssert(!self.identifier || [self.identifier isKindOfClass:[NSString class]], @"Don't mix and match SGListSection -title and -identifier properties.");
    return self.identifier;
}

- (void)setTitle:(NSString *)title {
    self.identifier = title;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)other {
    if (!other || ![other isMemberOfClass:self.class]) {
        return NO;
    }
    SGListSection *otherListSection = (SGListSection *)other;
    return [self.title isEqualToString:otherListSection.title] &&
           [self.items isEqual:otherListSection.items];
}

- (NSUInteger)hash {
    const NSInteger Prime = 31;
    NSInteger hash = 1;

    hash = hash * Prime * self.title.hash;
    hash = hash * Prime * self.items.hash;

    return hash;
}

@end
