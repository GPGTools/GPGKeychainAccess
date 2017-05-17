#import <ScriptingBridge/ScriptingBridge.h>

@interface MailApplication : SBApplication
- (SBElementArray *)accounts;
@end

@interface MailAccount : SBObject
@property (copy) NSArray *emailAddresses;  // The list of email addresses configured for an account
@property (copy) NSString *fullName;  // The users full name configured for an account
@end

