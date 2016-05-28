//
//  UIView+WDAutoLayout.m
//  WDAutoLayout
//
//  Created by 王迪 on 16/3/19.
//  Copyright © 2016年 wangdi. All rights reserved.
//

#import "UIView+WDAutoLayout.h"
#import "WDViewLayout.h"
#import "UITableView+WDAutoLayout.h"
#import <objc/runtime.h>

@implementation UIView (WDAutoLayout)
+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL systemSEL[] = {@selector(layoutSubviews)};
        SEL customerSEL[] = {@selector(wd_layoutSubviews)};
        for(int i = 0;i < sizeof(systemSEL) / sizeof(SEL);i++) {
            Method systemMethod = class_getInstanceMethod(self,systemSEL[i]);
            Method custmerMethod = class_getInstanceMethod(self,customerSEL[i]);
            method_exchangeImplementations(systemMethod, custmerMethod);
        }
    });
}

- (void)wd_addSubviews:(NSArray *)subViews
{
    if(!subViews.count) return;
    for(UIView *view in subViews) {
        if(![view isKindOfClass:[UIView class]]) continue;
        [self addSubview:view];
    }
}

- (WDViewLayout *)wd_layout
{
    WDViewLayout *layout = objc_getAssociatedObject(self, _cmd);
    if(!layout) {
        layout = [WDViewLayout layoutWithNeedAutoLayoutView:self];
        objc_setAssociatedObject(self, _cmd, layout, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[self.superview wd_layoutArray] addObject:layout];
    }
    return layout;
}

- (WDViewLayout *)wd_resetLayout
{
    WDViewLayout *oldLayout = self.wd_layout;
    WDViewLayout *newLayout = [WDViewLayout layoutWithNeedAutoLayoutView:self];
    objc_setAssociatedObject(self, @selector(wd_layout), newLayout, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.frame = CGRectZero;
    NSInteger index = 0;
    if (oldLayout) {
        index = [self.superview.wd_layoutArray indexOfObject:oldLayout];
        NSInteger count = self.superview.wd_layoutArray.count;
        if(index < count) {
            [self.superview.wd_layoutArray replaceObjectAtIndex:index withObject:newLayout];
        }
    } else {
        [self.superview.wd_layoutArray addObject:newLayout];
    }
    return newLayout;

}

- (NSMutableArray *)wd_layoutArray
{
    NSMutableArray *layoutArray = objc_getAssociatedObject(self, _cmd);
    if(!layoutArray) {
        layoutArray = [NSMutableArray array];
        objc_setAssociatedObject(self, _cmd, layoutArray, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return layoutArray;
}

- (void)setWd_widthEqualSubviews:(NSArray *)wd_widthEqualSubviews
{
    objc_setAssociatedObject(self, @selector(wd_widthEqualSubviews), wd_widthEqualSubviews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray *)wd_widthEqualSubviews
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setWd_heightEqualSubviews:(NSArray *)wd_heightEqualSubviews
{
    objc_setAssociatedObject(self, @selector(wd_heightEqualSubviews) , wd_heightEqualSubviews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray *)wd_heightEqualSubviews
{
    return objc_getAssociatedObject(self, _cmd);
}

- (UITableView *)wd_tableView
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setWd_tableView:(UITableView *)wd_tableView
{
    objc_setAssociatedObject(self, @selector(wd_tableView), wd_tableView, OBJC_ASSOCIATION_ASSIGN);
}

- (NSIndexPath *)wd_indexPath
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setWd_indexPath:(NSIndexPath *)wd_indexPath
{
    objc_setAssociatedObject(self, @selector(wd_indexPath), wd_indexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)wd_updateLayout
{
    [self.superview layoutSubviews];
}

- (void)wd_adjustCellSubviewFrame
{
    NSMutableArray *layoutArray = self.wd_layoutArray;
    if(!layoutArray.count) return;
    NSArray *cellSubviewFrames = [self.wd_tableView wd_subviewFramesWithIndexPath:self.wd_indexPath];
    if(cellSubviewFrames.count != layoutArray.count) {
        [self wd_adjustSubviewsFrame];
        return;
    }
    for(int i = 0;i < layoutArray.count;i++) {
        WDViewLayout *layout = layoutArray[i];
        UIView *view = layout.needAutoLayoutView;
        if(!view) continue;
        WDCellSubviewFrame *cellSubviewFrame = cellSubviewFrames[i];
        NSArray *subviewFrames = cellSubviewFrame.subviewFrames;
        view.frame = cellSubviewFrame.selfFrame;
        layout.didFinishedCache = YES;
        [view wd_enumerateCellAllSubviewWithSubviewFrames:subviewFrames];
    }
}

- (void)wd_enumerateCellAllSubviewWithSubviewFrames:(NSArray *)subviewFrames
{
    NSArray *layoutArray = self.wd_layoutArray;
    if(!layoutArray.count) return;
    if(layoutArray.count != subviewFrames.count) return;
    for(int i = 0;i < layoutArray.count;i++) {
        WDViewLayout *layout = layoutArray[i];
        UIView *view = layout.needAutoLayoutView;
        if(!view) continue;
        WDCellSubviewFrame *subviewFrame = subviewFrames[i];
        [view wd_enumerateCellAllSubviewWithSubviewFrames:subviewFrame.subviewFrames];
        layout.cellSubviewFrame = subviewFrame;
        layout.didFinishedCache = YES;
    }
}

- (void)wd_adjustSubviewsFrame
{
    NSMutableArray *layoutArray = self.wd_layoutArray;
    if(!layoutArray.count) return;
    for(int i = 0;i < layoutArray.count;i++) {
        WDViewLayout *layout = layoutArray[i];
        UIView *view = layout.needAutoLayoutView;
        if(!view) continue;
        if(layout.cellSubviewFrame) {
            view.frame = layout.cellSubviewFrame.selfFrame;
        } else {
            [layout startLayout];
        }
    }
}

- (void)wd_adjustMySelfFrame
{
    if([self isKindOfClass:[UITableViewCell class]] || (!self.wd_bottomViewArray.count && !self.wd_rightViewArray.count)) return;
    if(self.wd_layout.isDidFinishedCache) {
        self.wd_layout.didFinishedCache = NO;
        return;
    }
    CGFloat contentHeight = 0;
    CGFloat contentWidth = 0;
    if(self.wd_bottomViewArray.count) {
        for(UIView *subView in self.wd_bottomViewArray) {
            contentHeight = MAX(contentHeight, subView.wd_bottom);
        }
        contentHeight += self.wd_marginToBottom;
    }
    if(self.wd_rightViewArray.count) {
        for(UIView *subView in self.wd_rightViewArray) {
            contentWidth = MAX(contentWidth, subView.wd_right);
        }
        contentWidth += self.wd_marginToRight;
    }
    
    if([self isKindOfClass:[UIScrollView class]]) {
        UIScrollView *scrollView = (UIScrollView *)self;
        CGSize contentSize = scrollView.contentSize;
        if(contentWidth > 0) {
            contentSize.width = contentWidth;
        }
        if(contentHeight > 0) {
            contentSize.height = contentHeight;
        }
        if (contentSize.width <= 0) {
            contentSize.width = scrollView.wd_width;
        }
        if (!CGSizeEqualToSize(contentSize, scrollView.contentSize)) {
            scrollView.contentSize = contentSize;
        }
    } else {
        if(self.wd_bottomViewArray.count && ceil(self.wd_height) != ceil(contentHeight)) {
            self.wd_height = contentHeight;
            self.wd_layout.heightFix = YES;
        }
        
        if(self.wd_rightViewArray.count && ceil(self.wd_width) != ceil(contentWidth)) {

            self.wd_width = contentWidth;
            self.wd_layout.widthFix = YES;
        }
        if(self.wd_rightViewArray.count) {
            [self.wd_layout adjustHorizontalConstraint];
        }
        if(self.wd_bottomViewArray.count) {
            [self.wd_layout adjustVerticalConstraint];
        }
    }
}

- (void)wd_setupWidthEqualSubviews
{
    NSArray *views = self.wd_widthEqualSubviews;
    if(!views.count) return;
    [WDViewLayout setupWidthEqualSubViewsWithSubviewsArray:views];
}

- (void)wd_setupHeightEqualSubviews
{
    NSArray *views = self.wd_heightEqualSubviews;
    if(!views.count) return;
    [WDViewLayout setupHeightEqualSubViewsWithSubviewsArray:views];
}

- (void)wd_setupAutoLayout
{
    if(self.wd_autoLayoutArray.count) {
        CGFloat w = 0;
        CGFloat hormargin = 0;
        NSInteger rowCount = self.wd_rowCount;
        CGFloat autoLayoutHorMargin = self.wd_autoLayoutHormargin;
        CGFloat autoLayoutVerMargin = self.wd_autoLayoutVerMargin;
        CGFloat autoLayoutFixWidth = self.wd_autoLayoutFixWidth;
        if(self.wd_fixWidthLayout) {
            w = autoLayoutFixWidth;
            if(rowCount > 1) {
                hormargin = (self.wd_width - rowCount * w) / (rowCount - 1);
            }
        } else {
            w = (self.wd_width - (rowCount - 1) * autoLayoutHorMargin) / rowCount;
            hormargin = autoLayoutHorMargin;
        }
        
        UIView *refView = self;
        NSInteger count = self.wd_autoLayoutArray.count;
        for(int i = 0;i < count;i++) {
            UIView *view = self.wd_autoLayoutArray[i];
            if(i < self.wd_rowCount) {
                if(i == 0) {
                    view.wd_layout.leftEqualToView(refView).topSpaceToView(refView,autoLayoutVerMargin).width(w);
                } else {
                    view.wd_layout.leftSpaceToView(refView,hormargin).topEqualToView(refView).width(w);
                }
                refView = view;
            } else {
                refView = self.wd_autoLayoutArray[i % self.wd_rowCount];
                view.wd_layout.leftEqualToView(refView).topSpaceToView(refView,autoLayoutVerMargin).width(w);
            }
        }
    }
}

- (void)wd_layoutSubviews
{
    [self wd_layoutSubviews];
    [self wd_setupWidthEqualSubviews];
    [self wd_setupHeightEqualSubviews];
    [self wd_setupAutoLayout];
    NSArray *layoutArray = self.wd_layoutArray;
    if(layoutArray.count) {
        if([self isKindOfClass:NSClassFromString(@"UITableViewCellContentView")] && self.wd_tableView && self.wd_indexPath) {
            [self wd_adjustCellSubviewFrame];
        } else {
            [self wd_adjustSubviewsFrame];
        }
    }
    [self wd_adjustMySelfFrame];
}

- (void)setWd_didFinishedAutoLayout:(void (^)(CGRect))wd_didFinishedAutoLayout
{
    objc_setAssociatedObject(self, @selector(wd_didFinishedAutoLayout), wd_didFinishedAutoLayout, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(CGRect))wd_didFinishedAutoLayout
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setWd_bottomView:(UIView *)wd_bottomView
{
    if(!wd_bottomView) return;
    [self setWd_bottomViewArray:@[wd_bottomView]];
}

- (NSArray *)wd_autoLayoutArray
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setWd_autoLayoutArray:(NSArray *)wd_autoLayoutArray
{
    objc_setAssociatedObject(self, @selector(wd_autoLayoutArray), wd_autoLayoutArray, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)wd_autoLayoutFixWidth
{
    return [objc_getAssociatedObject(self, _cmd) doubleValue];
}

- (void)setWd_autoLayoutFixWidth:(CGFloat)wd_autoLayoutFixWidth
{
    objc_setAssociatedObject(self, @selector(wd_autoLayoutFixWidth), @(wd_autoLayoutFixWidth), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)wd_autoLayoutHormargin
{
    return [objc_getAssociatedObject(self, _cmd) doubleValue];

}

- (void)setWd_autoLayoutHormargin:(CGFloat)wd_autoLayoutHormargin
{
    objc_setAssociatedObject(self, @selector(wd_autoLayoutHormargin), @(wd_autoLayoutHormargin), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

- (CGFloat)wd_autoLayoutVerMargin
{
    return [objc_getAssociatedObject(self, _cmd) doubleValue];
}

- (void)setWd_autoLayoutVerMargin:(CGFloat)wd_autoLayoutVerMargin
{
    objc_setAssociatedObject(self, @selector(wd_autoLayoutVerMargin), @(wd_autoLayoutVerMargin), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

- (NSInteger)wd_rowCount
{
    return [objc_getAssociatedObject(self, _cmd) integerValue];

}

- (void)setWd_rowCount:(NSInteger)wd_rowCount
{
    objc_setAssociatedObject(self, @selector(wd_rowCount), @(wd_rowCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

- (BOOL)isWd_FixWidthLayout
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];

}

- (void)setWd_fixWidthLayout:(BOOL)wd_fixWidthLayout
{
    objc_setAssociatedObject(self, @selector(isWd_FixWidthLayout), @(wd_fixWidthLayout), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

- (UIView *)wd_bottomView
{
    NSArray *bottomViewArray = [self wd_bottomViewArray];
    if(!bottomViewArray.count) return nil;
    return bottomViewArray[0];
}

- (void)setWd_bottomViewArray:(NSArray *)wd_bottomViewArray
{
    objc_setAssociatedObject(self, @selector(wd_bottomViewArray), wd_bottomViewArray, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray *)wd_bottomViewArray
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setWd_marginToBottom:(CGFloat)wd_marginToBottom
{
    objc_setAssociatedObject(self, @selector(wd_marginToBottom), @(wd_marginToBottom), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)wd_marginToBottom
{
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}

- (void)wd_setupBottomViewWithBottomView:(UIView *)bottomView marginToBottom:(CGFloat)marginToBottom
{
    self.wd_bottomView = bottomView;
    self.wd_marginToBottom = marginToBottom;
}

- (void)wd_setupBottomViewWithBottomViewArray:(NSArray *)bottomViewArray marginToBottom:(CGFloat)marginToBottom
{
    self.wd_bottomViewArray = bottomViewArray;
    self.wd_marginToBottom = marginToBottom;
}

- (void)setWd_rightView:(UIView *)wd_rightView
{
    if(!wd_rightView) return;
    [self setWd_rightViewArray:@[wd_rightView]];
}

- (UIView *)wd_rightView
{
    NSArray *rightViewArray = [self wd_rightViewArray];
    if(!rightViewArray.count) return nil;
    return rightViewArray[0];
}

- (void)setWd_rightViewArray:(NSArray *)wd_rightViewArray
{
    objc_setAssociatedObject(self, @selector(wd_rightViewArray), wd_rightViewArray, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray *)wd_rightViewArray
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setWd_marginToRight:(CGFloat)wd_marginToRight
{
    objc_setAssociatedObject(self, @selector(wd_marginToRight), @(wd_marginToRight), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)wd_marginToRight
{
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}

- (void)wd_setupRightViewWithRightView:(UIView *)rightView marginToRight:(CGFloat)marginToRight
{
    self.wd_rightView = rightView;
    self.wd_marginToRight = marginToRight;
}

- (void)wd_setupRightViewWithRightViewArray:(NSArray *)rightViewArray marginToRight:(CGFloat)marginToRight
{
    self.wd_rightViewArray = rightViewArray;
    self.wd_marginToRight = marginToRight;
}

- (void)wd_setupAutoMarginFixWidthLayoutWithItemArray:(NSArray *)itemArray verticalMargin:(CGFloat)verticalMargin itemWidth:(CGFloat)itemWidth rowCount:(NSInteger)rowCount
{
    self.wd_autoLayoutFixWidth = itemWidth;
    self.wd_fixWidthLayout = YES;
    [self wd_setupAutoWidthFixMarginLayoutWithItemArray:itemArray horizontalMargin:0 verticalMargin:verticalMargin rowCount:rowCount];
}

- (void)wd_setupAutoWidthFixMarginLayoutWithItemArray:(NSArray *)itemArray horizontalMargin:(CGFloat)horizontalMargin verticalMargin:(CGFloat)verticalMargin rowCount:(NSInteger)rowCount
{
    self.wd_autoLayoutArray = itemArray;
    self.wd_autoLayoutHormargin = horizontalMargin;
    self.wd_autoLayoutVerMargin = verticalMargin;
    self.wd_rowCount = rowCount;
    [self wd_setupBottomViewWithBottomView:itemArray.lastObject marginToBottom:verticalMargin];
}

@end

@implementation UIView (WDAutoLayoutFrame)

- (void)setWd_left:(CGFloat)wd_left
{
    CGRect frame = self.frame;
    frame.origin.x = wd_left;
    self.frame = frame;
}

- (CGFloat)wd_left
{
    return self.frame.origin.x;
}

- (void)setWd_top:(CGFloat)wd_top
{
    CGRect frame = self.frame;
    frame.origin.y = wd_top;
    self.frame = frame;
}

- (CGFloat)wd_top
{
    return self.frame.origin.y;
}

-(void)setWd_right:(CGFloat)wd_right
{
    CGRect frame = self.frame;
    frame.origin.x = wd_right - frame.size.width;
    self.frame = frame;
}

- (CGFloat)wd_right
{
    return self.frame.size.width + self.frame.origin.x;
}

-(void)setWd_bottom:(CGFloat)wd_bottom
{
    CGRect frame = self.frame;
    frame.origin.y = wd_bottom - frame.size.height;
    self.frame = frame;
}

- (CGFloat)wd_bottom
{
    return self.frame.size.height + self.frame.origin.y;
}

-(void)setWd_centerX:(CGFloat)wd_centerX
{
    CGPoint center = self.center;
    center.x = wd_centerX;
    self.center = center;
}

- (CGFloat)wd_centerX
{
    return self.center.x;
}

-(void)setWd_centerY:(CGFloat)wd_centerY
{
    CGPoint center = self.center;
    center.y = wd_centerY;
    self.center = center;
}

- (CGFloat)wd_centerY
{
    return self.center.y;
}

- (void)setWd_width:(CGFloat)wd_width
{
    if(self.wd_layout.widthEqualHeightConstraint) {
        if(wd_width != self.wd_height) return;
    }
    CGRect frame = self.frame;
    frame.size.width = wd_width;
    if(self.wd_layout.heightEqualWidthConstraint) {
        frame.size.height = wd_width;
    }
    self.frame = frame;
}

- (CGFloat)wd_width
{
    return self.frame.size.width;
}

- (void)setWd_height:(CGFloat)wd_height
{
    if(self.wd_layout.heightEqualWidthConstraint) {
        if(wd_height != self.wd_width) return;
    }
    CGRect frame = self.frame;
    frame.size.height = wd_height;
    if(self.wd_layout.widthEqualHeightConstraint) {
        frame.size.width = wd_height;
    }
    self.frame = frame;
}

- (CGFloat)wd_height
{
    return self.frame.size.height;
}


- (CGPoint)wd_origin
{
    return self.frame.origin;
}

- (void)setWd_origin:(CGPoint)wd_origin
{
    CGRect frame = self.frame;
    frame.origin = wd_origin;
    self.frame = frame;
}

- (CGSize)wd_size
{
    return self.frame.size;
}

- (void)setWd_size:(CGSize)wd_size
{
    CGRect frame = self.frame;
    frame.size = wd_size;
    self.frame = frame;
}

@end

@implementation UILabel (WDAutoLayout)

- (BOOL)isAttributedContent
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setAttributedContent:(BOOL)attributedContent
{
    objc_setAssociatedObject(self, @selector(isAttributedContent), @(attributedContent), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
