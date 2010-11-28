/*
 Created by davelopper at users.sourceforge.net on Sun Feb 03 2002.
 Modified by Roman Zechmeister
 
 Copyright (C) 2002-2006 Mac GPG Project.
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




@interface GPGOptions : NSObject {
    NSString        *path;
    NSMutableArray	*optionFileLines;
    NSMutableArray	*optionNames;
    NSMutableArray	*optionValues;
    NSMutableArray	*optionStates;
    NSMutableArray	*optionLineNumbers;
    BOOL			hasModifications;
}

+ (BOOL) homeDirectoryChanged;
- (id) initWithPath:(NSString *)path;
- (void) setOptionValue:(NSString *)value atIndex:(unsigned)index;
- (void) setEmptyOptionValueAtIndex:(unsigned)index;
- (void) setOptionName:(NSString *)name atIndex:(unsigned)index;
- (void) setOptionState:(BOOL)flag atIndex:(unsigned)index;
- (void) addOptionNamed:(NSString *)name;
- (void) addOptionNamed:(NSString *)name value:(NSString *)value state:(BOOL)state;
- (void) insertOptionNamed:(NSString *)name atIndex:(unsigned)index;
- (void) removeOptionAtIndex:(unsigned)index;
- (unsigned) moveOptionsAtIndexes:(NSArray *)indexes toIndex:(unsigned)index;
- (NSArray *) optionNames;
- (NSArray *) optionValues;
- (NSArray *) optionStates;
- (NSString *) optionValueForName:(NSString *)name;
- (void) setOptionValue:(NSString *)value forName:(NSString *)name;
- (void) setEmptyOptionValueForName:(NSString *)name;
- (BOOL) optionStateForName:(NSString *)name;
- (void) setOptionState:(BOOL)state forName:(NSString *)name;
- (BOOL) subOptionState:(NSString *)subOptionName forName:(NSString *)optionName;
- (void) setSubOption:(NSString *)subOptionName state:(BOOL)state forName:(NSString *)optionName;
- (NSString *) subOptionValue:(NSString *)subOptionName state:(BOOL *)statePtr forName:(NSString *)optionName;
- (void) setSubOption:(NSString *)subOptionName value:(NSString *)value state:(BOOL)state forName:(NSString *)optionName;
- (void) reloadOptions;
- (void) saveOptions;
- (NSArray *) allOptionValuesForName:(NSString *)name;
- (NSArray *) activeOptionValuesForName:(NSString *)name;

@end

@interface GPGAgentOptions : GPGOptions {}

+ (void)gpgAgentFlush;

@end
