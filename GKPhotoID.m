/*
 Copyright © Roman Zechmeister, 2010
 
 Dieses Programm ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung dieses Programms erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import "GKPhotoID.h"
#import "GKKey.h"


@implementation GKPhotoID
@synthesize image;
@synthesize hashID;
@synthesize status;

- (id)initWithImage:(NSImage *)aImage hashID:(NSString *)aHashID status:(NSInteger)aStatus {
	[self init];
	
	image = [aImage retain];
	hashID = [aHashID retain];
	status = aStatus;
	
	return self;
}

- (void) dealloc {
	[image release];
	[hashID release];
	
	[super dealloc];
}


@end
