//
//  GKPasswordStrengthIndicator.m
//  GPG Keychain
//
//  Created by Mento on 28.06.18.
//

#import "GKPasswordStrengthIndicator.h"

@implementation GKPasswordStrengthIndicator

- (instancetype)initWithCoder:(NSCoder *)decoder {
	self = [super initWithCoder:decoder];
	if (!self) {
		return nil;
	}
	
	borderColor = [NSColor colorWithCalibratedWhite:0.71 alpha:1];
	backgroundColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1];
	
	NSColor* color1 = [NSColor colorWithCalibratedRed: 0.808 green: 0.241 blue: 0.241 alpha: 1];
	NSColor* color2 = [NSColor colorWithCalibratedRed: 0.868 green: 0.83 blue: 0.213 alpha: 1];
	NSColor* color3 = [NSColor colorWithCalibratedRed: 0.373 green: 0.848 blue: 0.19 alpha: 1];
	
	
	gradient = [[NSGradient alloc] initWithColorsAndLocations:
				color1, 0.23,
				[color1 blendedColorWithFraction: 0.5 ofColor: color2], 0.27,
				color2, 0.36,
				[color2 blendedColorWithFraction: 0.5 ofColor: color3], 0.43,
				color3, 0.50, nil];
	
	return self;
}


- (void)drawRect:(NSRect)dirtyRect {
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	NSSize size = self.bounds.size;
	CGFloat width = size.width;
	CGFloat height = size.height;
	CGFloat barWidth = width - 3;
	CGFloat barHeight = 8;
	CGFloat xOffset = (width - barWidth) / 2;
	CGFloat yOffset = (height - barHeight) / 2 + 0.5;
	CGFloat radius = barHeight / 2;
	
	double minValue = self.minValue;
	double maxValue = self.maxValue;
	double value = self.doubleValue;
	double ratio = (value - minValue) / (maxValue - minValue);
	CGFloat filledWidth = barWidth * ratio;
	
	
	NSColor *barColor = [gradient interpolatedColorAtLocation:ratio];
	
	
	
	
	// Construct the BezierPath.
	NSPoint line1Start = NSMakePoint(radius + xOffset, yOffset);
	NSPoint line1End = NSMakePoint(barWidth - radius + xOffset, yOffset);
	NSPoint arc1Center = NSMakePoint(line1End.x, line1End.y + radius);
	NSPoint arc2Center = NSMakePoint(line1Start.x, line1Start.y + radius);
	
	NSBezierPath *border = [NSBezierPath bezierPath];
	[border moveToPoint:line1Start];
	[border appendBezierPathWithArcWithCenter:arc1Center radius:radius startAngle:270 endAngle:90];
	[border appendBezierPathWithArcWithCenter:arc2Center radius:radius startAngle:90 endAngle:270];
	[border setLineWidth:1.0];
	
	
	// Fill the background.
	[backgroundColor setFill];
	[border fill];
	
	
	// Draw the bar.
	[[NSGraphicsContext currentContext] saveGraphicsState];
	NSBezierPath *clipPath = [NSBezierPath bezierPath];
	[clipPath appendBezierPathWithRect:NSMakeRect(0, 0, filledWidth + xOffset, height)];
	[clipPath setClip];
	
	[barColor setFill];
	[border fill];
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	
	// Draw the border.
	[borderColor set];
	[border stroke];
	
	
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}

@end

