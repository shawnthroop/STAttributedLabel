//
//  STAttributedLabel.m
//  Simple Label
//
//  Created by Shawn Throop on 05/10/15.
//  Copyright © 2015 Silent H Designs. All rights reserved.
//

#import "STAttributedLabel.h"

#import <UIKit/UIGestureRecognizerSubclass.h>

NSString * const STAttributedRangeAttribute = @"STAttributedRangeAttribute";
NSString * const STAttributedMentionIdentifier = @"STAttributedMention";


@interface STAttributedTapRecognizer : UIGestureRecognizer

@property (nonatomic) NSTimeInterval longPressDuration;
@property (nonatomic) NSUInteger allowableMovement;

- (NSTimeInterval)elapsedTime;

@end


@implementation STAttributedRange

- (instancetype)initWithRangeType:(NSString *)rangeType range:(NSRange)range value:(id<NSCoding>)value
{
    if (self = [super init]) {
        if (rangeType.length == 0 || range.location == NSNotFound || range.length == 0) { return nil; }
        _rangeType = rangeType;
        _range = range;
        _value = value;
    }
    
    return self;
}


#pragma mark - NSCoding


- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
        _rangeType = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(rangeType))];
        _range = [[aDecoder decodeObjectForKey:NSStringFromSelector(@selector(range))] rangeValue];
        _value = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(value))];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.rangeType forKey:NSStringFromSelector(@selector(rangeType))];
    [aCoder encodeObject:[NSValue valueWithRange:self.range] forKey:NSStringFromSelector(@selector(range))];
    [aCoder encodeObject:self.value forKey:NSStringFromSelector(@selector(value))];
}

@end



#pragma mark - STAttributedLabel


@interface STAttributedLabel () <UIGestureRecognizerDelegate>

@property (nonatomic, readonly) NSTextContainer *textContainer;
@property (nonatomic) NSAttributedString *formattedAttributedString;
@property (nonatomic) NSMutableDictionary *rangeAttributes;
@property (nonatomic) NSRange selectedRange;
@property (nonatomic) STAttributedTapRecognizer *pressRecognizer;

@end



@implementation STAttributedLabel

- (instancetype)initWithLayoutManager:(NSLayoutManager *)layoutManager textStorage:(NSTextStorage *)textStorage frame:(CGRect)frame;
{
    if ([super initWithFrame:frame]) {
        _layoutManager = layoutManager ?: [[NSLayoutManager alloc] init];
        _textStorage = textStorage ?: [[NSTextStorage alloc] init];
        _textContainer = [[NSTextContainer alloc] init];
        
        // add text container to layout manager
        [_layoutManager addTextContainer:_textContainer];
        
        // clean out the text storage's layout managers (precautionary)
        NSArray *layoutManagers = _textStorage.layoutManagers;
        for (NSLayoutManager *manager in layoutManagers) {
            [_textStorage removeLayoutManager:manager];
        }
        
        // pair the layout manager and text storage
        [_textStorage addLayoutManager:_layoutManager];
        
        _rangeAttributes = [[NSMutableDictionary alloc] init];
        _selectedAttributes = @{NSForegroundColorAttributeName: [UIColor blueColor]};
        _verticalTextAlignment = STVerticalTextAlignmentTop;
        self.backgroundColor = [UIColor clearColor];
        
        _pressRecognizer = [[STAttributedTapRecognizer alloc] initWithTarget:self action:@selector(didPress:)];
        _pressRecognizer.delegate = self;
        [self addGestureRecognizer:_pressRecognizer];
        
        _handleLongPress = YES;
    }
    
    return self;
}


- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithLayoutManager:nil textStorage:nil frame:frame];
}




#pragma mark - Public


- (void)setAttributedText:(NSAttributedString *)attributedText
{
    [self updateFormattedAttributedStringForAttributedString:attributedText];
}



- (void)setVerticalTextAlignment:(STVerticalTextAlignment)verticalTextAlignment
{
    _verticalTextAlignment = verticalTextAlignment;
    [self setNeedsDisplay];
}

- (void)setExclusionPath:(UIBezierPath *)exclusionPath
{
    _exclusionPath = [exclusionPath copy];
    
    NSArray *exclusionPaths = nil;
    if (_exclusionPath) {
        exclusionPaths = [[NSArray alloc] initWithObjects:_exclusionPath, nil];
    }
    
    self.textContainer.exclusionPaths = exclusionPaths;
    [self setNeedsDisplay];
}


- (void)setHandleLongPress:(BOOL)handleLongPress
{
    _handleLongPress = handleLongPress;
    
    self.pressRecognizer.longPressDuration = _handleLongPress ? 0.5 : 0.0;
}

//- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled
//{
//    [super setUserInteractionEnabled:userInteractionEnabled];
//    self.pressRecognizer.enabled = userInteractionEnabled;
//}



#pragma mark - Private


- (void)layoutSubviews
{
    [super layoutSubviews];
    self.textContainer.size = self.bounds.size;
    [self setNeedsDisplay];
}



- (void)drawRect:(CGRect)rect
{
    NSRange glyphRange = [_layoutManager glyphRangeForTextContainer:_textContainer];
    CGPoint glyphOrigin = [self glyphOriginInView];
    
    [_layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:glyphOrigin];
    [_layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:glyphOrigin];
}



- (CGPoint)glyphOriginInView;
{
    CGPoint textOrigin = CGPointZero;
    
    // optimized so if vertical alignment is STVerticalTextAlignmentTop, then CGPointZero is out glyphOrigin. Don't need to check for textBounds
    if (self.verticalTextAlignment != STVerticalTextAlignmentTop) {
        CGRect textBounds = [_layoutManager usedRectForTextContainer:_textContainer];
        textBounds.size.width = ceil(textBounds.size.width);
        textBounds.size.height = ceil(textBounds.size.height);
        
        // offset the origin according to vertical alignment (or not if the textBounds are taller than self.bounds)
        if (textBounds.size.height < self.bounds.size.height) {
            CGFloat paddingHeight = (self.bounds.size.height - textBounds.size.height);
            
            if (self.verticalTextAlignment == STVerticalTextAlignmentMiddle) {
                paddingHeight /= 2.0f;
            }
            
            textOrigin.y = paddingHeight;
        }

    }
    
    
    return textOrigin;
}




#pragma mark - Attributes


- (void)setAttributes:(NSDictionary *)attributes forAttributedRangeType:(NSString *)rangeType
{
    if (!rangeType) {
        return;
    }
    
    if (attributes) {
        [_rangeAttributes setObject:attributes forKey:rangeType];
    } else {
        [_rangeAttributes removeObjectForKey:rangeType];
    }
    
    if (self.attributedText.length != 0) {
        [self updateFormattedAttributedStringForAttributedString:self.attributedText];
    }
}




#pragma mark - Selection


- (void)setSelectedRange:(NSRange)selectedRange
{
    _selectedRange = selectedRange;
    
    [self updateFormattedAttributedStringForAttributedString:self.attributedText];
}


- (STAttributedRange *)attributedRangeAtPoint:(CGPoint)point// effectiveRange:(NSRangePointer)effectiveRange;
{
    if (_textStorage.length == 0) {
        return nil;
    }
    
    CGPoint glyphOrigin = [self glyphOriginInView];
    point.x -= glyphOrigin.x;
    point.y -= glyphOrigin.y;
    
    NSUInteger touchedGlyphIndex = [_layoutManager glyphIndexForPoint:point inTextContainer:_textContainer];
    
    NSRange lineRange;
    CGRect lineRect = [_layoutManager lineFragmentUsedRectForGlyphAtIndex:touchedGlyphIndex effectiveRange:&lineRange];
    if (CGRectContainsPoint(lineRect, point) == NO) {
        return nil;
    }
    
    __block STAttributedRange *selectedAttributedRange = nil;
    
    [self.attributedText enumerateAttribute:STAttributedRangeAttribute inRange:lineRange options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if ([value isKindOfClass:[STAttributedRange class]]) {
            STAttributedRange *attributedRange = (STAttributedRange *)value;
            
            if ((touchedGlyphIndex >= attributedRange.range.location) && touchedGlyphIndex < NSMaxRange(attributedRange.range)) {
                selectedAttributedRange = attributedRange;
                *stop = YES;
            }
        }
    }];
    
    return selectedAttributedRange;
}






#pragma mark - Formatting strings


- (void)updateFormattedAttributedStringForAttributedString:(NSAttributedString *)attributedString;
{
    NSAttributedString *formattedAttributedString = [self formattedAttributedStringFromAttributedString:attributedString];
    
    _formattedAttributedString = formattedAttributedString;
    _attributedText = attributedString;
    [_textStorage setAttributedString:_formattedAttributedString];
    
    [self setNeedsDisplay];
}



- (NSAttributedString *)formattedAttributedStringFromAttributedString:(NSAttributedString *)attributedString;
{
    if (!attributedString) {
        return nil;
    }
    
    // create a mutable string
    NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedString];
    
    // enumerate all STAttributedRanges
    [attributedString enumerateAttribute:STAttributedRangeAttribute inRange:NSMakeRange(0, attributedString.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if ([value isKindOfClass:[STAttributedRange class]]) {
            STAttributedRange *attributedRange = (STAttributedRange *)value;
            
            [mutableString removeAttribute:STAttributedRangeAttribute range:range];
            
            // if we have attributes, add them
            NSDictionary *attributes = [self.rangeAttributes objectForKey:attributedRange.rangeType];
            if (attributes) {
                [mutableString addAttributes:attributes range:range];
            }
        }
    }];
    
    // Apply selected attributes
    if (self.selectedRange.location != NSNotFound && self.selectedRange.length > 0 && self.selectedRange.length < mutableString.length) {
        NSDictionary *selectedAttributes = [self.selectedAttributes copy];
        
        if (selectedAttributes) {
            [mutableString addAttributes:selectedAttributes  range:self.selectedRange];
        }
    }
    
    return [mutableString attributedSubstringFromRange:NSMakeRange(0, mutableString.length)];
}


#pragma mark - Gestures


- (void)didPress:(STAttributedTapRecognizer *)press;
{
    static STAttributedRange *selectedAttributedRange;
    
    if (press.state == UIGestureRecognizerStateBegan) {
        CGPoint touchDown = [press locationInView:press.view];
        selectedAttributedRange = [self attributedRangeAtPoint:touchDown];
        
        if (selectedAttributedRange) {
            self.selectedRange = selectedAttributedRange.range;
        }
        
    } else if (press.state >= UIGestureRecognizerStateEnded) {
        // remove highlighted string
        self.selectedRange = NSMakeRange(NSNotFound, 0);
        
        if (press.state == UIGestureRecognizerStateEnded && selectedAttributedRange && self.tapHandler) {
            BOOL isLongPress = NO;
            
            if (self.handleLongPress) {
                isLongPress = [press elapsedTime] > press.longPressDuration;
            }
            
            // handle tap
            self.tapHandler(isLongPress, selectedAttributedRange);
        }
        
        // nil the static value
        selectedAttributedRange = nil;
    }
}


// only

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if (self.textStorage.length == 0) {
        return NO;
    }

    STAttributedRange *selectedAttributedRange = [self attributedRangeAtPoint:[touch locationInView:self]];
    
    return selectedAttributedRange != nil;
}


@end



@interface STAttributedTapRecognizer () {
    NSDate *_touchDownTime;
    CGPoint _touchDownPoint;
}

@property (nonatomic, copy) NSString *tapIdentifier;

@end


@implementation STAttributedTapRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    if (self = [super initWithTarget:target action:action]) {
        _longPressDuration = 0.5;
        _allowableMovement = 5;
    }
    
    return self;
}

- (NSTimeInterval)elapsedTime
{
    if (!_touchDownTime) {
        return 0;
    }
    
    return [[NSDate date] timeIntervalSinceDate:_touchDownTime];
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    if (touches.count == 1) {
        UITouch *touch = touches.anyObject;
        if (touch) {
            _touchDownTime = [NSDate date];
            _touchDownPoint = [touch locationInView:self.view];
            
            NSString *tapIdentifier = [[NSUUID UUID] UUIDString];
            self.tapIdentifier = tapIdentifier;
            
            self.state = UIGestureRecognizerStateBegan;
            
            if (self.longPressDuration > 0.0) {
                __weak typeof(self) welf = self;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.longPressDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    typeof(welf) strongSelf = welf;
                    if (!strongSelf) {
                        return;
                    }
                    
                    if ([strongSelf.tapIdentifier isEqualToString:tapIdentifier]) {
                        strongSelf.state = UIGestureRecognizerStateEnded;
                    }
                });
            }
            
        }
        
    } else {
        self.state = UIGestureRecognizerStateFailed;
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    
    if (touches.count == 1 && _touchDownTime) {
        UITouch *touch = touches.anyObject;
        
        if (touch) {
            CGPoint locationOfTouch = [touch locationInView:self.view];
            CGPoint translation = CGPointMake(fabs(_touchDownPoint.x - locationOfTouch.x), fabs(_touchDownPoint.y - locationOfTouch.y));
//            NSLog(@"translation: %@", NSStringFromCGPoint(translation));
            
            if (translation.x > self.allowableMovement || translation.y > self.allowableMovement) {
                self.state = UIGestureRecognizerStateFailed;
                [self reset];
            } else {
                self.state = UIGestureRecognizerStateChanged;
            }
        }
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    self.state = UIGestureRecognizerStateCancelled;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    if (self.state < UIGestureRecognizerStateEnded) {
        self.state = UIGestureRecognizerStateEnded;
    }
}

- (void)reset
{
    [super reset];
    _touchDownPoint = CGPointZero;
    _touchDownTime = nil;
    self.tapIdentifier = nil;
}

@end
