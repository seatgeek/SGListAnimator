//
//  CollectionViewCell.m
//  TestTableView
//
//  Created by David McNerney on 2/17/16.
//  Copyright © 2016 SeatGeek. All rights reserved.
//

#import "CollectionViewCell.h"

@implementation CollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    self.backgroundColor = [UIColor grayColor];
    [self addSubview:self.textLabel];

    return self;
}

- (void)layoutSubviews {
    self.textLabel.frame = self.bounds;
}

@synthesize textLabel = _textLabel;
- (UILabel *)textLabel {
    if (_textLabel) {
        return _textLabel;
    }

    _textLabel = [UILabel new];
    _textLabel.font = [UIFont boldSystemFontOfSize:14];
    _textLabel.textAlignment = NSTextAlignmentCenter;

    return _textLabel;
}

@end
