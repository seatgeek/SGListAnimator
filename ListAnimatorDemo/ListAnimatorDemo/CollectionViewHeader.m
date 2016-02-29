//
//  CollectionViewHeader.m
//  TestTableView
//
//  Created by David McNerney on 2/17/16.
//  Copyright © 2016 SeatGeek. All rights reserved.
//

#import "CollectionViewHeader.h"

@implementation CollectionViewHeader

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    self.backgroundColor = [UIColor colorWithRed:86./255. green:130./255. blue:3./255. alpha:1];

    [self addSubview:self.textLabel];

    return self;
}

- (void)layoutSubviews {
    self.textLabel.frame = CGRectInset(self.bounds, 5, 5);
}

@synthesize textLabel = _textLabel;
- (UILabel *)textLabel {
    if (_textLabel) {
        return _textLabel;
    }

    _textLabel = [UILabel new];
    _textLabel.font = [UIFont systemFontOfSize:12];
    _textLabel.textColor = [UIColor whiteColor];

    return _textLabel;
}

@end
