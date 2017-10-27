/*
 * ACEDrawingView: https://github.com/acerbetti/ACEDrawingView
 *
 * Copyright (c) 2016 Yury Zenko
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#import "ACEDrawingTextView.h"
#import <QuartzCore/QuartzCore.h>


CG_INLINE CGSize CGAffineTransformGetScale(CGAffineTransform t)
{
    return CGSizeMake(sqrt(t.a * t.a + t.c * t.c), sqrt(t.b * t.b + t.d * t.d)) ;
}

#define defaultHeight  50

@interface ACEDrawingTextView () <UIGestureRecognizerDelegate, UITextViewDelegate>

@property (nonatomic, assign) CGFloat globalInset;

@property (nonatomic, assign) CGRect initialBounds;
@property (nonatomic, assign) CGFloat initialDistance;

@property (nonatomic, assign) CGPoint beginningPoint;
@property (nonatomic, assign) CGPoint beginningCenter;

@property (nonatomic, assign) CGPoint touchLocation;

@property (nonatomic, assign) CGFloat deltaAngle;
@property (nonatomic, assign) CGRect beginBounds;

@property (nonatomic, strong) CAShapeLayer *border;
@property (nonatomic, strong) UITextView *labelTextView;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *resizeRightButton;
@property (nonatomic, strong) UIButton *resizeLeftButton;

@property (nonatomic, assign) CGFloat lastVelocity;
@property (nonatomic, assign, getter=isShowingEditingHandles) BOOL showEditingHandles;

@end

@implementation ACEDrawingTextView

- (void)refresh
{
    if (self.superview) {
        CGSize scale = CGAffineTransformGetScale(self.superview.transform);
        CGAffineTransform t = CGAffineTransformMakeScale(scale.width, scale.height);
        [self.closeButton setTransform:CGAffineTransformInvert(t)];
        [self.border removeFromSuperlayer];
        
        if (self.isShowingEditingHandles) {
            [self.labelTextView.layer addSublayer:self.border];
        }
    }
}

-(void)didMoveToSuperview
{
    [super didMoveToSuperview];
    [self refresh];
}

- (void)setFrame:(CGRect)newFrame
{
    [super setFrame:newFrame];
    [self refresh];
}

- (id)initWithFrame:(CGRect)frame
{
    if (frame.size.width < 300)     frame.size.width = 300;
    if (frame.size.height < 50)    frame.size.height = 50;
    
    self = [super initWithFrame:frame];
    if (self) {
        self.globalInset = 36;
        
        self.backgroundColor = [UIColor clearColor];
        [self setAutoresizingMask:(UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth)];
        self.borderColor = [UIColor redColor];
        
        self.labelTextView = [[UITextView alloc] initWithFrame:CGRectInset(self.bounds, self.globalInset, self.globalInset/3)];
        [self.labelTextView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight)];
        [self.labelTextView setClipsToBounds:YES];
        self.labelTextView.delegate = self;
        self.labelTextView.backgroundColor = [UIColor clearColor];
        self.labelTextView.tintColor = [UIColor redColor];
        self.labelTextView.textColor = [UIColor whiteColor];
        self.labelTextView.text = @"";
        self.labelTextView.scrollEnabled = NO;
        
        self.border = [CAShapeLayer layer];
        self.border.strokeColor = self.borderColor.CGColor;
        self.border.fillColor = nil;
        self.border.lineDashPattern = @[@4, @3];
        
        [self insertSubview:self.labelTextView atIndex:0];
        
        self.resizeLeftButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0,
                                                                           self.globalInset, self.bounds.size.height)];
        [self.resizeLeftButton setAutoresizingMask:(UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleHeight)];
        self.resizeLeftButton.backgroundColor = [UIColor clearColor];
        self.resizeLeftButton.userInteractionEnabled = YES;
        self.resizeLeftButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        [self addSubview:self.resizeLeftButton];
        
        self.resizeRightButton = [[UIButton alloc] initWithFrame:CGRectMake(self.bounds.size.width - self.globalInset, 0,
                                                                            self.globalInset, self.bounds.size.height)];
        [self.resizeRightButton setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleHeight)];
        self.resizeRightButton.backgroundColor = [UIColor clearColor];
        self.resizeRightButton.userInteractionEnabled = YES;
        self.resizeRightButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [self addSubview:self.resizeRightButton];
        
        self.closeButton = [[UIButton alloc] initWithFrame:CGRectMake(2*self.globalInset/3, 0, 2*self.globalInset/3, 2*self.globalInset/3)];
        [self.closeButton setAutoresizingMask:(UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin)];
        self.closeButton.backgroundColor = [UIColor clearColor];
        self.closeButton.userInteractionEnabled = YES;
        [self addSubview:self.closeButton];
        
        UIPanGestureRecognizer *moveGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveGesture:)];
        [self addGestureRecognizer:moveGesture];
        
        UITapGestureRecognizer *singleTapShowHide = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(contentTapped:)];
        [self addGestureRecognizer:singleTapShowHide];
        
        UITapGestureRecognizer *closeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeTap:)];
        [self.closeButton addGestureRecognizer:closeTap];
        
        UIPanGestureRecognizer *resizeRightGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizeGesture:)];
        [self.resizeRightButton addGestureRecognizer:resizeRightGesture];
        
        UIPanGestureRecognizer *resizeLeftGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizeGesture:)];
        [self.resizeLeftButton addGestureRecognizer:resizeLeftGesture];
        
        [moveGesture requireGestureRecognizerToFail:closeTap];
        
        [self setEnableMoveRestriction:NO];
        [self setEnableClose:YES];
        [self setEnableResizing:YES];
        [self setShowsContentShadow:NO];
        
        [self showEditingHandles];
        [self.labelTextView becomeFirstResponder];
    }
    return self;
}

- (void)layoutSubviews
{
    if (self.labelTextView) {
        self.border.path = [UIBezierPath bezierPathWithRect:self.labelTextView.bounds].CGPath;
        self.border.frame = self.labelTextView.bounds;
    }
}

#pragma mark - Set Control Buttons

- (void)setEnableClose:(BOOL)value
{
    _enableClose = value;
    [self.closeButton setHidden:!_enableClose];
    [self.closeButton setUserInteractionEnabled:_enableClose];

}

- (void)setEnableResizing:(BOOL)value
{
    _enableResizing = value;
    [self.resizeRightButton setHidden:!_enableResizing];
    [self.resizeRightButton setUserInteractionEnabled:_enableResizing];
    
    [self.resizeLeftButton setHidden:!_enableResizing];
    [self.resizeLeftButton setUserInteractionEnabled:_enableResizing];
    
}

- (void)setShowsContentShadow:(BOOL)showShadow
{
    _showsContentShadow = showShadow;
    
    if (_showsContentShadow) {
        [self.layer setShadowColor:[UIColor blackColor].CGColor];
        [self.layer setShadowOffset:CGSizeMake(0, 5)];
        [self.layer setShadowOpacity:1.0];
        [self.layer setShadowRadius:4.0];
    } else {
        [self.layer setShadowColor:[UIColor clearColor].CGColor];
        [self.layer setShadowOffset:CGSizeZero];
        [self.layer setShadowOpacity:0.0];
        [self.layer setShadowRadius:0.0];
    }
}

- (void)setCloseImage:(UIImage *)image
{
    _closeImage = image;
    [self.closeButton setImage:_closeImage forState:UIControlStateNormal];
}

- (void)setLeftResizeImage:(UIImage *)image
{
    _leftResizeImage = image;
    [self.resizeLeftButton setImage:_leftResizeImage forState:UIControlStateNormal];
    
}

- (void)setRightResizeImage:(UIImage *)image
{
    _rightResizeImage = image;
    [self.resizeRightButton setImage:_rightResizeImage forState:UIControlStateNormal];
    
}

#pragma mark - Set Text Field

- (void)setFontName:(NSString *)name
{
    if (name.length > 0) {
        _fontName = name;
        self.labelTextView.font = [UIFont fontWithName:_fontName size:self.fontSize];
        [self.labelTextView adjustsWidthToFillItsContents];
    }
}

- (void)setFontSize:(CGFloat)size
{
    _fontSize = size;
    self.labelTextView.font = [UIFont fontWithName:self.fontName size:_fontSize];
}

- (void)setTextColor:(UIColor *)color
{
    _textColor = color;
    self.labelTextView.textColor = _textColor;
}

- (void)setBorderColor:(UIColor *)color
{
    _borderColor = color;
    self.border.strokeColor = _borderColor.CGColor;
}

- (void)setTextAlpha:(CGFloat)alpha
{
    self.labelTextView.alpha = alpha;
}

- (CGFloat)textAlpha
{
    return self.labelTextView.alpha;
}

#pragma mark - Bounds

- (void)hideEditingHandles
{
    self.showEditingHandles = NO;
    if (self.isEnableClose)       self.closeButton.hidden = YES;
    if (self.isenableResizing) {
        self.resizeRightButton.hidden = YES;
        self.resizeLeftButton.hidden = YES;
    }
    
    [self.labelTextView resignFirstResponder];
    
    [self refresh];
    
    if([self.delegate respondsToSelector:@selector(textViewDidHideEditingHandles:)]) {
        [self.delegate textViewDidHideEditingHandles:self];
    }
}

- (void)showEditingHandles
{
    if ([self.delegate respondsToSelector:@selector(textViewWillShowEditingHandles:)]) {
        [self.delegate textViewWillShowEditingHandles:self];
    }
    
    self.showEditingHandles = YES;
    if (self.isEnableClose)       self.closeButton.hidden = NO;
    if (self.isenableResizing) {
        self.resizeRightButton.hidden = NO;
        self.resizeLeftButton.hidden = NO;
    }
    
    [self refresh];
    
    if ([self.delegate respondsToSelector:@selector(textViewDidShowEditingHandles:)]) {
        [self.delegate textViewDidShowEditingHandles:self];
    }
}

- (void)resizeInRect:(CGRect)rect {}

#pragma mark - Gestures

- (void)contentTapped:(UITapGestureRecognizer*)tapGesture
{
    if (self.isShowingEditingHandles) {
        [self hideEditingHandles];
        [self.superview bringSubviewToFront:self];
    } else {
        [self showEditingHandles];
    }
}

- (void)closeTap:(UITapGestureRecognizer *)recognizer
{
    [self removeFromSuperview];
    
    if ([self.delegate respondsToSelector:@selector(textViewDidClose:)]) {
        [self.delegate textViewDidClose:self];
    }
}

- (void)moveGesture:(UIPanGestureRecognizer *)recognizer
{
    if (!self.isShowingEditingHandles) {
        [self showEditingHandles];
    }
    self.touchLocation = [recognizer locationInView:self.superview];
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.beginningPoint = self.touchLocation;
        self.beginningCenter = self.center;
        
        [self setCenter:[self estimatedCenter]];
        self.beginBounds = self.bounds;
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        [self setCenter:[self estimatedCenter]];
        
        if ([self.delegate respondsToSelector:@selector(textViewDidChangeEditing:)]) {
            [self.delegate textViewDidChangeEditing:self];
        }
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self setCenter:[self estimatedCenter]];
        
        if ([self.delegate respondsToSelector:@selector(textViewDidEndEditing:)]) {
            [self.delegate textViewDidEndEditing:self];
        }
    }
}

- (CGPoint)estimatedCenter
{
    CGPoint newCenter;
    CGFloat newCenterX = self.beginningCenter.x + (self.touchLocation.x - self.beginningPoint.x);
    CGFloat newCenterY = self.beginningCenter.y + (self.touchLocation.y - self.beginningPoint.y);
    if (self.isEnableMoveRestriction) {
        if (!(newCenterX - 0.5 * CGRectGetWidth(self.frame) > 0 &&
              newCenterX + 0.5 * CGRectGetWidth(self.frame) < CGRectGetWidth(self.superview.bounds))) {
            newCenterX = self.center.x;
        }
        if (!(newCenterY - 0.5 * CGRectGetHeight(self.frame) > 0 &&
              newCenterY + 0.5 * CGRectGetHeight(self.frame) < CGRectGetHeight(self.superview.bounds))) {
            newCenterY = self.center.y;
        }
        newCenter = CGPointMake(newCenterX, newCenterY);
    } else {
        newCenter = CGPointMake(newCenterX, newCenterY);
    }
    return newCenter;
}

- (void)resizeGesture:(UIPanGestureRecognizer *)recognizer {
    BOOL isRightButtonRecognizer = [self.resizeRightButton.gestureRecognizers containsObject:recognizer];
    BOOL isLeftButtonRecognizer = [self.resizeLeftButton.gestureRecognizers containsObject:recognizer];
    
    if ((isRightButtonRecognizer && !self.resizeRightButton.enabled) || (isLeftButtonRecognizer && !self.resizeLeftButton.enabled)) {
        return;
    }
    
    CGPoint location = [recognizer locationInView:self.superview];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.touchLocation = location;
        self.initialBounds = self.frame;
        if([self.delegate respondsToSelector:@selector(textViewDidBeginEditing:)]) {
            [self.delegate textViewDidBeginEditing:self];
            
            if (self.resizeRightButton.isHighlighted) {
                self.resizeLeftButton.enabled = NO;
                self.resizeLeftButton.selected = NO;
            }
            
            if (self.resizeLeftButton.isHighlighted) {
                self.resizeRightButton.enabled = NO;
                self.resizeRightButton.selected = NO;
            }
        }
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        if (self.touchLocation.x != location.x) {
            CGFloat leftPosition = 0;
            CGFloat rightPosition = 0;
            CGFloat dif = location.x - self.touchLocation.x;
            if (isRightButtonRecognizer) { rightPosition = dif; }
            else { leftPosition = dif; }

            [self setFrame: [self estimateFrame:self.initialBounds leftPosition:leftPosition rightPosition:rightPosition]];
            self.initialBounds = self.frame;
            self.touchLocation = location;
        }
        
        if ([self.delegate respondsToSelector:@selector(textViewDidChangeEditing:)]) {
            [self.delegate textViewDidChangeEditing:self];
        }
        
        [self.labelTextView adjustsWidthToFillItsContents];
        
    }
    else if ([recognizer state] == UIGestureRecognizerStateEnded) {
        self.resizeRightButton.enabled = YES;
        self.resizeLeftButton.enabled = YES;
        
        if ([self.delegate respondsToSelector:@selector(textViewDidEndEditing:)]) {
            [self.delegate textViewDidEndEditing:self];
        }
        
        [self.labelTextView adjustsWidthToFillItsContents];
    }
}

- (CGRect) estimateFrame:(CGRect) frame leftPosition:(CGFloat) leftPosition rightPosition:(CGFloat) rightPosition
{
    CGRect temRect = frame;
    CGFloat xPos = temRect.origin.x + leftPosition;
    CGFloat width = temRect.size.width - leftPosition + rightPosition;
    if ( width > self.globalInset*3) {
        temRect.size.width = width;
        temRect.origin.x = xPos;
    }
    return temRect;
}

#pragma mark - UITextView Delegate

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    if (self.isShowingEditingHandles) {
        return YES;
    }
    [self contentTapped:nil];
    return NO;
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
    if ([self.delegate respondsToSelector:@selector(textViewDidStartEditing:)]) {
        [self.delegate textViewDidStartEditing:self];
    }
    
    [textView adjustsWidthToFillItsContents];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    if ([self.delegate respondsToSelector:@selector(textViewDidEndEditing:)]) {
        [self.delegate textViewDidEndEditing:self];
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    if (!self.isShowingEditingHandles) {
        [self showEditingHandles];
    }
    [textView adjustsWidthToFillItsContents];
}

#pragma mark - Additional Properties

- (BOOL)isEditing
{
    return self.isShowingEditingHandles;
}

- (NSString *)textValue
{
    return self.labelTextView.text;
}

@end


#pragma mark - UITextField Category for DynamicFontSize

@implementation UITextView (DynamicFontSize)

static const NSUInteger ACELVMaximumFontSize = 101;
static const NSUInteger ACELVMinimumFontSize = 9;

- (void)adjustsWidthToFillItsContents
{
    CGSize rectSize = [self sizeThatFits:CGSizeMake(self.bounds.size.width, CGFLOAT_MAX)];
    
    float h1 = 0;
    
    if (ceilf(rectSize.height) < self.bounds.size.height && ceilf(rectSize.height) < defaultHeight) {
        h1 = defaultHeight;
    }
    else if (ceilf(rectSize.height) < self.bounds.size.height && ceilf(rectSize.height) > defaultHeight) {
        h1 = self.bounds.size.height;
    }
    else {
        h1 = ceilf(rectSize.height) + (self.superview.bounds.size.height - self.bounds.size.height);
    }
    
    CGRect viewFrame = self.superview.frame;
    viewFrame.size.height = h1;
    [self.superview setFrame:viewFrame];
}

@end

#pragma mark - ACEDrawingLabelViewTransform

@interface ACEDrawingTextViewTransform ()
@property (nonatomic, assign) CGAffineTransform transform;
@property (nonatomic, assign) CGPoint center;
@property (nonatomic, assign) CGRect bounds;
@end

@implementation ACEDrawingTextViewTransform

+ (instancetype)transform:(CGAffineTransform)transform atCenter:(CGPoint)center withBounds:(CGRect)bounds
{
    ACEDrawingTextViewTransform *t = [ACEDrawingTextViewTransform new];
    t.transform = transform;
    t.center = center;
    t.bounds = bounds;
    
    return t;
}

@end
