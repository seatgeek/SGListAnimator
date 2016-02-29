//
//  CollectionViewExample.m
//  TestTableView
//
//  Created by David McNerney on 2/17/16.
//  Copyright © 2016 SeatGeek. All rights reserved.
//

#import "CollectionViewExample.h"
#import "SGListAnimator.h"
#import "SGListSection.h"
#import "CollectionViewCell.h"
#import "CollectionViewHeader.h"


static BOOL DoExtraBrutalStressTest = NO;
static NSInteger CountAvailableItemsExtraBrutalStressTest = 1000;


static NSString * const CellReuseIdentifier = @"CellReuseIdentifier";
static NSString * const HeaderReuseIdentifier = @"HeaderReuseIdentifier";


@interface CollectionViewExample () <UICollectionViewDataSource, UICollectionViewDelegate>

// Table view backing data
@property (nonatomic) SGListAnimator *animator;

// Subviews
@property (nonatomic) UICollectionView *collectionView;

// Misc state
@property (nonatomic) NSInteger displayIteration;
@property (nonatomic) NSTimer *stressTestTimer;

@end


@implementation CollectionViewExample

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UIBarButtonItem *stressBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Stress Test" style:UIBarButtonItemStylePlain target:self action:@selector(handleStressTestButton)];
    self.navigationItem.leftBarButtonItem = stressBarButtonItem;

    UIBarButtonItem *nextButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Next" style:UIBarButtonItemStylePlain target:self action:@selector(handleNextButton)];
    self.navigationItem.rightBarButtonItem = nextButtonItem;

    [self.view addSubview:self.collectionView];
    self.collectionView.frame = self.view.bounds;
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    self.navigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Collection View" image:nil selectedImage:nil];

    [self setUpAnimator];
    self.displayIteration = -1;

    // Show first iteration
    [self handleNextButton];
}

#pragma mark - Display

- (void)setUpAnimator {
    self.animator = [SGListAnimator new];
    self.animator.doSectionMoves = YES;
    self.animator.doIntraSectionMoves = YES;
    self.animator.doInterSectionMoves = YES;
    self.animator.collectionView = self.collectionView;
}

- (NSArray<SGListSection *> *)getNextStressTestSections {
    // We go from one randomly generated data set to the next

    NSMutableArray *availableSectionTitles = [@[ @"A", @"B", @"C", @"D", @"E" ] mutableCopy];
    NSMutableArray *availableItemTitles = [@[
        @"a", @"b", @"c", @"d", @"e", @"f", @"g", @"h", @"i", @"j", @"k", @"l", @"m", @"n", @"o", @"p", @"q", @"r", @"s", @"t", @"u", @"v", @"w", @"x", @"y", @"z",
    ] mutableCopy];
    if (DoExtraBrutalStressTest) {
        [availableSectionTitles addObjectsFromArray:@[ @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z" ]];
        for (NSInteger i = 0; i < CountAvailableItemsExtraBrutalStressTest; ++i) {
            [availableItemTitles addObject:[NSString stringWithFormat:@"%li", (long)i]];
        }
    }

    NSInteger countSections = arc4random_uniform((u_int32_t)availableSectionTitles.count) + 1;
    NSMutableArray<SGListSection *> *sections = [NSMutableArray new];
    for (NSInteger sectionIndex = 0; sectionIndex < countSections; ++sectionIndex) {
        if (availableItemTitles.count == 0) {
            break;
        }

        SGListSection *section = [SGListSection new];
        NSInteger titleArrayIndex = arc4random_uniform((u_int32_t)availableSectionTitles.count);
        section.title = availableSectionTitles[titleArrayIndex];
        [availableSectionTitles removeObjectAtIndex:titleArrayIndex];

        NSMutableArray<NSString *> *items = [NSMutableArray new];
        NSInteger countItems = arc4random_uniform((u_int32_t)availableItemTitles.count) + 1;
        for (NSInteger itemIndex = 0; itemIndex < countItems; ++itemIndex) {
            NSInteger itemArrayIndex = arc4random_uniform((u_int32_t)availableItemTitles.count);
            NSString *item = availableItemTitles[itemArrayIndex];
            [availableItemTitles removeObjectAtIndex:itemArrayIndex];
            [items addObject:item];
        }
        section.items = items;

        [sections addObject:section];
    }

    return sections;
}

- (NSArray<SGListSection *> *)getNextDisplaySections {
    ++self.displayIteration;

    static NSArray<NSString *> *iterations = nil;
    if (!iterations) {
        iterations = @[
            // See SGListAnimatorTests.m for documentation of this string format
            @"",
            @"A.a",
            @"A.abcdefghij",
            @"A.abcdefghij,B.k",
            @"A.abcdefghij,B.klmnopq",
            @"A.abcde,B.klmnopq",
            @"A.abc,B.def,C.ghi,D.jkl",
            @"A.abcz,D.jkl,B.def,E.mno",
            @"A.abc,B.def",
            @"B.de,A.abcf",
            @"A.abc,B.defg",
            @"A.acde,B.bklmnopq",
            @"A.a,B.bdefghijck",            // too many changes by current limit rule
            @"B.bdefghijck,A.a",            // section move
            @"B.edbfghijck,A.a",            // intra-section move
            @"A.ae,B.ghidbfjck",            // section move, intra-section move, and inter-section move all at once
            @"A.a",
            @"B.a",
            @"A.a,B.b",
            @"A.abcde,B.f",
            @"A.a,B.fedcb",
            @"A.afde,C.ghi,D.j",
            @"A.af,C.g",
            @"A.af,D.g",
            @"A.afg",
            @"",
            @"A.abc",
            @"A.ijkadbecfgh",
            @"A.a,B.bcdef",
            @"B.abcdef",
            @"B.acdef",
            @"B.acf",

            // Used to crash
            @"C.wbimgkqaxvslonp,D.terczhfdujy",
            @"A.dhvlrxbjg,B.o,C.kszwquc",
        ];
    }
    return self.displayIteration < iterations.count ? [self sectionsForString:iterations[self.displayIteration]] : @[];
}

- (NSArray<SGListSection *> *)sectionsForString:(NSString *)input {
    NSMutableArray<SGListSection *> *sections = [NSMutableArray new];
    for (NSString *sectionString in [self splitString:input byString:@","]) {
        NSArray<NSString *> *titleAndItems = [self splitString:sectionString byString:@"."];
        SGListSection *section = [SGListSection new];
        section.title = titleAndItems[0];
        section.items = [self divideStringIntoCharacters:titleAndItems[1]];
        [sections addObject:section];
    }
    return sections;
}

- (NSArray<NSString *> *)splitString:(NSString *)input byString:(NSString *)separator {
    if (input.length == 0) {
        return @[];
    }
    return [input componentsSeparatedByString:separator];
}

- (NSArray<NSString *> *)divideStringIntoCharacters:(NSString *)input {
    NSMutableArray *output = [NSMutableArray new];
    for (NSInteger i = 0; i < input.length; ++i) {
        NSString *character = [input substringWithRange:NSMakeRange(i, 1)];
        [output addObject:character];
    }
    return output;
}

#pragma mark - Actions

- (void)handleStressTestButton {
    if (self.stressTestTimer) {
        [self.stressTestTimer invalidate];
        self.stressTestTimer = nil;
    } else {
        self.stressTestTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(doNextStressTestIteration) userInfo:nil repeats:YES];
    }
}

- (void)handleNextButton {
    [self.animator transitionCollectionViewToSections:[self getNextDisplaySections]];
}

#pragma mark - Stress test

- (void)doNextStressTestIteration {
    [self.animator transitionCollectionViewToSections:[self getNextStressTestSections]];
}


#pragma mark - UICollectionView

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.animator.currentSections.count;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {

    CollectionViewHeader *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:HeaderReuseIdentifier forIndexPath:indexPath];
    headerView.textLabel.text = self.animator.currentSections[indexPath.section].title;
    return headerView;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.animator.currentSections[section].items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    CollectionViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:CellReuseIdentifier forIndexPath:indexPath];
    cell.textLabel.text = self.animator.currentSections[indexPath.section].items[indexPath.row];
    return cell;
}

#pragma mark - Subview getters

- (UICollectionView *)collectionView {
    if (_collectionView) { return _collectionView; }
    
    UICollectionViewFlowLayout *flowLayout = [UICollectionViewFlowLayout new];
    flowLayout.itemSize = CGSizeMake(50,50);
    flowLayout.headerReferenceSize = flowLayout.itemSize;

    _collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:flowLayout];
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    [_collectionView registerClass:[CollectionViewCell class] forCellWithReuseIdentifier:CellReuseIdentifier];
    [_collectionView registerClass:[CollectionViewHeader class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:HeaderReuseIdentifier];
    _collectionView.backgroundColor = [UIColor whiteColor];

    return _collectionView;
}

@end

