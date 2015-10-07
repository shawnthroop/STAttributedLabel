//
//  STAttributedLabel.h
//  Simple Label
//
//  Created by Shawn Throop on 05/10/15.
//  Copyright © 2015 Silent H Designs. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, STVerticalTextAlignment) {
    STVerticalTextAlignmentTop,
    STVerticalTextAlignmentMiddle,
    STVerticalTextAlignmentBottom
};


// use as attribute creating NSAttributedStrings with [attribute,value]
extern NSString * const STAttributedRangeAttribute;


extern NSString * const STAttributedMentionIdentifier;




@interface STAttributedRange : NSObject <NSCoding>

@property (nonatomic, readonly, copy) NSString *rangeType;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly) id<NSCoding> value;

- (instancetype)initWithRangeType:(NSString *)rangeType range:(NSRange)range value:(id<NSCoding>)value;

@end




typedef void (^STAttributedLabelTapHandler)(BOOL isLongPress, STAttributedRange *selectedAttributedRange);


@interface STAttributedLabel : UIView

@property (nonatomic, readonly) NSLayoutManager *layoutManager;
@property (nonatomic, readonly) NSTextStorage *textStorage;

@property (nonatomic) NSAttributedString *attributedText;

@property (nonatomic) STVerticalTextAlignment verticalTextAlignment;
@property (nonatomic) NSDictionary *selectedAttributes;
@property (nonatomic) BOOL handleLongPress;

@property (nonatomic) UIBezierPath *exclusionPath;

@property (nonatomic, copy) STAttributedLabelTapHandler tapHandler;

- (instancetype)initWithLayoutManager:(NSLayoutManager *)layoutManager textStorage:(NSTextStorage *)textStorage frame:(CGRect)frame;

- (void)setAttributes:(NSDictionary *)attributes forAttributedRangeType:(NSString *)rangeType;

@end
