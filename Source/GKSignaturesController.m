//
//  GKSignaturesController.m
//  GPG Keychain
//
//  Created by Mento on 10.07.18.
//

#import "GKSignaturesController.h"

@implementation GKSignaturesController
// This ArrayController shows the self signature always on top.

- (NSSortDescriptor *)primarySortDescriptor {
	if (!_primarySortDescriptor) {
		_primarySortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"selfSignature" ascending:NO];
	}
	return _primarySortDescriptor;
}
- (void)setSortDescriptors:(NSArray<NSSortDescriptor *> *)value {
	NSMutableArray *mutableValue = [[NSMutableArray alloc] initWithArray:value];
	[mutableValue insertObject:self.primarySortDescriptor atIndex:0];
	
	_sortDescriptors = mutableValue;
	[super didChangeArrangementCriteria];
	_sortDescriptors = value;
}
- (void)setContent:(id)content {
	NSArray *oldSortDescriptors = _sortDescriptors;
	
	NSMutableArray *mutableValue = [[NSMutableArray alloc] initWithArray:_sortDescriptors];
	[mutableValue insertObject:self.primarySortDescriptor atIndex:0];
	
	_sortDescriptors = mutableValue;
	[super setContent:content];
	_sortDescriptors = oldSortDescriptors;
}
- (NSArray<NSSortDescriptor *> *)sortDescriptors {
	if (_sortDescriptors.count == 0) {
		return @[self.primarySortDescriptor];
	}
	return _sortDescriptors;
};
@end

