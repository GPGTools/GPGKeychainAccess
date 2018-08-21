//
//  GKSignaturesController.h
//  GPG Keychain
//
//  Created by Mento on 10.07.18.
//

@interface GKSignaturesController : NSArrayController {
	NSSortDescriptor *_primarySortDescriptor;
	NSArray<NSSortDescriptor *> *_sortDescriptors;
}
@property (nonatomic, readonly) NSSortDescriptor *primarySortDescriptor;
@end

