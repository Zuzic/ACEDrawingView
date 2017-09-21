/*
 * ACEDrawingView: https://github.com/acerbetti/ACEDrawingView
 *
 * Copyright (c) 2016 Matthew Jackson
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

CG_INLINE CGPoint CGRectGetCenter(CGRect rect)
{
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

CG_INLINE CGRect CGRectScale(CGRect rect, CGFloat wScale, CGFloat hScale)
{
    return CGRectMake(rect.origin.x * wScale, rect.origin.y * hScale, rect.size.width * wScale, rect.size.height * hScale);
}

CG_INLINE CGFloat CGPointGetDistance(CGPoint point1, CGPoint point2)
{
    CGFloat fx = (point2.x - point1.x);
    CGFloat fy = (point2.y - point1.y);
    
    return sqrt((fx*fx + fy*fy));
}

CG_INLINE CGFloat CGAffineTransformGetAngle(CGAffineTransform t)
{
    return atan2(t.b, t.a);
}


CG_INLINE CGSize CGAffineTransformGetScale(CGAffineTransform t)
{
    return CGSizeMake(sqrt(t.a * t.a + t.c * t.c), sqrt(t.b * t.b + t.d * t.d)) ;
}

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
@property (nonatomic, strong) UIButton *rotateButton;
@property (nonatomic, strong) UIButton *closeButton;

@property (nonatomic, assign) CGFloat lastScale;


@property (nonatomic, assign, getter=isShowingEditingHandles) BOOL showEditingHandles;

@end

@implementation ACEDrawingTextView

- (void)refresh
{
    if (self.superview) {
        CGSize scale = CGAffineTransformGetScale(self.superview.transform);
        CGAffineTransform t = CGAffineTransformMakeScale(scale.width, scale.height);
        [self.closeButton setTransform:CGAffineTransformInvert(t)];
        [self.rotateButton setTransform:CGAffineTransformInvert(t)];
        
        if (self.isShowingEditingHandles) {
            [self.labelTextView.layer addSublayer:self.border];
        } else {
            [self.border removeFromSuperlayer];
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
    if (frame.size.width < 75)     frame.size.width = 75;
    if (frame.size.height < 25)    frame.size.height = 25;
    
    self = [super initWithFrame:frame];
    if (self) {
        self.globalInset = 12;
        
        self.backgroundColor = [UIColor clearColor];
        [self setAutoresizingMask:(UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth)];
        self.borderColor = [UIColor redColor];
        
        self.labelTextView = [[UITextView alloc] initWithFrame:CGRectInset(self.bounds, self.globalInset, self.globalInset)];
        [self.labelTextView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight)];
        [self.labelTextView setClipsToBounds:YES];
        self.labelTextView.delegate = self;
        self.labelTextView.backgroundColor = [UIColor clearColor];
        self.labelTextView.tintColor = [UIColor redColor];
        self.labelTextView.textColor = [UIColor whiteColor];
        self.labelTextView.text = @"";
        
        self.border = [CAShapeLayer layer];
        self.border.strokeColor = self.borderColor.CGColor;
        self.border.fillColor = nil;
        self.border.lineDashPattern = @[@4, @3];
        
        [self insertSubview:self.labelTextView atIndex:0];
        
        self.closeButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, self.globalInset * 2, self.globalInset * 2)];
        [self.closeButton setAutoresizingMask:(UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin)];
        self.closeButton.backgroundColor = [UIColor whiteColor];
        self.closeButton.layer.cornerRadius = self.globalInset - 5;
        self.closeButton.userInteractionEnabled = YES;
        [self addSubview:self.closeButton];
        
        self.rotateButton = [[UIButton alloc] initWithFrame:CGRectMake(self.bounds.size.width-self.globalInset*2, self.bounds.size.height-self.globalInset*2, self.globalInset*2, self.globalInset*2)];
        [self.rotateButton setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleTopMargin)];
        self.rotateButton.backgroundColor = [UIColor whiteColor];
        self.rotateButton.layer.cornerRadius = self.globalInset - 5;
        self.rotateButton.contentMode = UIViewContentModeCenter;
        self.rotateButton.userInteractionEnabled = YES;
        [self addSubview:self.rotateButton];
        
        UIPanGestureRecognizer *moveGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveGesture:)];
        [self addGestureRecognizer:moveGesture];
        
        UITapGestureRecognizer *singleTapShowHide = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(contentTapped:)];
        [self addGestureRecognizer:singleTapShowHide];
        
        UITapGestureRecognizer *closeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeTap:)];
        [self.closeButton addGestureRecognizer:closeTap];
        
        UIPinchGestureRecognizer *resizeGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(resizeGesture:)];
        [self addGestureRecognizer:resizeGesture];
        
        UIPanGestureRecognizer *panRotateGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rotateViewPanGesture:)];
        [self.rotateButton addGestureRecognizer:panRotateGesture];
        
        [moveGesture requireGestureRecognizerToFail:closeTap];
        
        [self setEnableMoveRestriction:NO];
        [self setEnableClose:YES];
        [self setEnableRotate:NO];
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

- (void)setEnableRotate:(BOOL)value
{
    _enableRotate = value;
    [self.rotateButton setHidden:!_enableRotate];
    [self.rotateButton setUserInteractionEnabled:_enableRotate];
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

- (void)setRotateImage:(UIImage *)image
{
    _rotateImage = image;
    [self.rotateButton setImage:_rotateImage forState:UIControlStateNormal];
    
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

//- (void)setAttributedPlaceholder:(NSAttributedString *)attributedPlaceholder
//{
//    _attributedPlaceholder = attributedPlaceholder;
//    [self.labelTextField setAttributedPlaceholder:attributedPlaceholder];
//    [self.labelTextField adjustsWidthToFillItsContents];
//}

#pragma mark - Bounds

- (void)hideEditingHandles
{
    self.showEditingHandles = NO;
    
    if (self.isEnableClose)       self.closeButton.hidden = YES;
    if (self.isEnableRotate)      self.rotateButton.hidden = YES;
    
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
    if (self.isEnableRotate)      self.rotateButton.hidden = NO;
    
    [self refresh];
    
    if ([self.delegate respondsToSelector:@selector(textViewDidShowEditingHandles:)]) {
        [self.delegate textViewDidShowEditingHandles:self];
    }
}

- (void)resizeInRect:(CGRect)rect
{
    [self.labelTextView adjustsFontSizeToFillRect:rect];
}

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
        
        if ([self.delegate respondsToSelector:@selector(textViewDidBeginEditing:)]) {
            [self.delegate textViewDidBeginEditing:self];
        }
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

- (void)rotateViewPanGesture:(UIPanGestureRecognizer *)recognizer
{
    self.touchLocation = [recognizer locationInView:self.superview];
    
    CGPoint center = CGRectGetCenter(self.frame);
    
    if ([recognizer state] == UIGestureRecognizerStateBegan) {
        self.deltaAngle = atan2(self.touchLocation.y-center.y, self.touchLocation.x-center.x)-CGAffineTransformGetAngle(self.transform);
        
        self.initialBounds = self.bounds;
        self.initialDistance = CGPointGetDistance(center, self.touchLocation);
        
        if([self.delegate respondsToSelector:@selector(textViewDidBeginEditing:)]) {
            [self.delegate textViewDidBeginEditing:self];
        }
    } else if ([recognizer state] == UIGestureRecognizerStateChanged) {
        float ang = atan2(self.touchLocation.y-center.y, self.touchLocation.x-center.x);
        
        float angleDiff = self.deltaAngle - ang;
        [self setTransform:CGAffineTransformMakeRotation(-angleDiff)];
        [self setNeedsDisplay];
        
        if ([self.delegate respondsToSelector:@selector(textViewDidChangeEditing:)]) {
            [self.delegate textViewDidChangeEditing:self];
        }
    } else if ([recognizer state] == UIGestureRecognizerStateEnded) {
        if ([self.delegate respondsToSelector:@selector(textViewDidEndEditing:)]) {
            [self.delegate textViewDidEndEditing:self];
        }
    }
}

- (void)resizeGesture:(UIPinchGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.lastScale = 1.0;
        self.initialBounds = self.bounds;
        
        if([self.delegate respondsToSelector:@selector(textViewDidBeginEditing:)]) {
            [self.delegate textViewDidBeginEditing:self];
        }
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGFloat scale = 1.0 - (self.lastScale - recognizer.scale);
        
        CGRect scaleRect = CGRectScale(self.initialBounds, scale, 1);
        
        [self setBounds:scaleRect];
        [self.labelTextView adjustsFontSizeToFillRect:scaleRect];
         self.lastScale = 1.0;
    }
    else if ([recognizer state] == UIGestureRecognizerStateEnded) {
        if ([self.delegate respondsToSelector:@selector(textViewDidEndEditing:)]) {
            [self.delegate textViewDidEndEditing:self];
        }
    }
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

- (void)textViewDidEndEditing:(UITextView *)textView
{
    if ([self.delegate respondsToSelector:@selector(textViewDidStartEditing:)]) {
        [self.delegate textViewDidStartEditing:self];
    }
    
    [textView adjustsWidthToFillItsContents];
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

- (void)adjustsFontSizeToFillRect:(CGRect)newBounds
{
    CGFloat viewOffset = 24;
    NSString *text = (![self.text isEqualToString:@""]) ? self.text : @"";
    NSCharacterSet *charSet = [NSCharacterSet newlineCharacterSet];
    NSArray *separatedByNewlineCharacter = [text componentsSeparatedByCharactersInSet:charSet];
    
    for (NSUInteger i = ACELVMaximumFontSize; i > ACELVMinimumFontSize; i--) {
        CGFloat viewHeight = CGRectGetHeight(self.frame) - viewOffset;
       
        if (separatedByNewlineCharacter.count > 1) {
            viewHeight = self.font.pointSize * separatedByNewlineCharacter.count + viewOffset;
        }
        
        CGSize rectSize = [self sizeThatFits:CGSizeMake(CGFLOAT_MAX, viewHeight)];
        
        if (rectSize.height <= CGRectGetHeight(newBounds)) {
            ((ACEDrawingTextView *)self.superview).fontSize = (CGFloat)i-1;
            break;
        }
    }
}

- (void)adjustsWidthToFillItsContents
{
    CGFloat viewOffset = 24;
    CGFloat viewHeight = CGRectGetHeight(self.frame) - viewOffset;
    NSString *text = (![self.text isEqualToString:@""]) ? self.text : @"";
    NSCharacterSet *charSet = [NSCharacterSet newlineCharacterSet];
    NSArray *separatedByNewlineCharacter = [text componentsSeparatedByCharactersInSet:charSet];
    if (separatedByNewlineCharacter.count > 1) {
        viewHeight = self.font.pointSize * separatedByNewlineCharacter.count + viewOffset;
    }
    
    CGSize rectSize = [self sizeThatFits:CGSizeMake(CGFLOAT_MAX, viewHeight)];
   
    float w1 = (ceilf(rectSize.width) + viewOffset < self.superview.bounds.size.width - viewOffset) ? self.superview.bounds.size.width : ceilf(rectSize.width) + viewOffset;
    float h1 =(ceilf(rectSize.height) + viewOffset < self.superview.bounds.size.height - viewOffset) ? self.superview.bounds.size.height : ceilf(rectSize.height) + viewOffset;
    
    CGRect viewFrame = self.superview.frame;
    viewFrame.size.width = w1;
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
