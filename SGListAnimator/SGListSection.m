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
    SGListSection *section = self.new;
    section.title = title;
    section.items = items;
    return section;
}

+ (nonnull instancetype)sectionWithIdentifier:(nonnull NSString *)identifier items:(nonnull NSArray *)items {
    SGListSection *section = self.new;
    section.identifier = identifier;
    section.items = items;
    return section;
}

#pragma mark - Setters

- (void)setTitle:(NSString *)title {
    _title = title;
    self.identifier = title;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    SGListSection *copy = SGListSection.new;
    copy.title = self.title;
    copy.identifier = self.identifier;
    copy.items = self.items.copy;
    return copy;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)other {
    if (!other || ![other isMemberOfClass:self.class]) {
        return NO;
    }
    SGListSection *otherListSection = (SGListSection *)other;
    return [self.identifier isEqualToString:otherListSection.identifier] &&
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
