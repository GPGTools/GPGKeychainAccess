//
//  GPGOptions.h
//  GPGPreferences and MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Sun Feb 03 2002.
//
//
//  Copyright (C) 2002-2006 Mac GPG Project.
//  
//  This code is free software; you can redistribute it and/or modify it under
//  the terms of the GNU Lesser General Public License as published by the Free
//  Software Foundation; either version 2.1 of the License, or (at your option)
//  any later version.
//  
//  This code is distributed in the hope that it will be useful, but WITHOUT ANY
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
//  details.
//  
//  You should have received a copy of the GNU Lesser General Public License
//  along with this program; if not, visit <http://www.gnu.org/> or write to the
//  Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, 
//  MA 02111-1307, USA.
//  
//  More info at <http://macgpg.sourceforge.net/>
//

#ifndef GPGOPTIONS_H
#define GPGOPTIONS_H

#include <Foundation/Foundation.h>
#include <MacGPGME/GPGDefines.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


/*!
 *  @const      GPGUserDefaultsSuiteName
 *  @abstract   Name of the user defaults domain global for all MacGPGME-based
 *              applications (<code>net.sourceforge.macgpg</code>).
 */
GPG_EXPORT NSString * const GPGUserDefaultsSuiteName;

/*!
 *  @const      GPGOpenPGPExecutablePathKey
 *  @abstract   Name of the user defaults key containing the default path to the
 *              <code>gpg</code> executable (<code>GPGOpenPGPExecutablePath</code>).
 */
GPG_EXPORT NSString * const GPGOpenPGPExecutablePathKey;

/*!
 *  @const      GPGDefaultsDidChangeNotification
 *  @abstract   Posted after defaults in the @link ////macgpg/c/const/GPGUserDefaultsSuiteName GPGUserDefaultsSuiteName \@link defaults domain have been changed.
 *  @discussion Object is (currently) nil.
 *
 *              This notification is also posted by the distributed notification
 *              center. object is also nil.
 */
GPG_EXPORT NSString * const GPGDefaultsDidChangeNotification;


/*!
 *  @class      GPGOptions
 *  @abstract   Represents GnuPG configuration options.
 *  @discussion GPGOptions class allows you to retrieve options used by GnuPG,
 *              as defined in <a href="http://macgpg.sf.net/" target="_blank">GPGPreferences</a>,
 *              from GnuPG configuration file, read by the executable.
 *
 *              You can also set options and save them, though this should be
 *              the job of GPGPreferences only.
 *
 *              Options are defined by a name, a state (active or not), and, 
 *              optionally (sic), a value.
 *
 *              Some options (e.g. <code>keyserver-options</code>) can have
 *              sub-options too.
 */
@interface GPGOptions : NSObject
{
    NSString        *path;
    NSMutableArray	*optionFileLines;
    NSMutableArray	*optionNames;
    NSMutableArray	*optionValues;
    NSMutableArray	*optionStates;
    NSMutableArray	*optionLineNumbers;
    BOOL			hasModifications;
}


/*!
 *  @method     homeDirectoryChanged
 *  @abstract   Returns whether user changed GnuPG's home directory, i.e.
 *              <code>@link //macgpg/occ/clm/GPGOptions/homeDirectory homeDirectory@/link</code>
 *              is equal or not to 
 *              <code>@link //macgpg/occ/instm/GPGEngine/homeDirectory homeDirectory@/link</code>
 *              (GPGEngine).
 */
+ (BOOL) homeDirectoryChanged;


/*!
 *  @method     setDefaultValue:forKey:
 *  @abstract   Sets default in GPGUserDefaultsSuiteName defaults suite.
 *  @discussion Posts a @link //macgpg/c/const/GPGDefaultsDidChangeNotification GPGDefaultsDidChangeNotification@/link
 *              notification. If <i>value</i> is nil, default is removed.
 *  @param      value The defaults value
 *  @param      key The defaults key
 */
+ (void) setDefaultValue:(id)value forKey:(NSString *)key;


- (id) initWithPath:(NSString *)path;

/*!
 *  @methodgroup Setting options
 */

/*!
 *  @method     setOptionValue:atIndex:
 *  @abstract   (brief description)
 *  @discussion If <i>value</i> is nil, option is removed.
 *  @param      value (description)
 *  @param      index (description)
 */
- (void) setOptionValue:(NSString *)value atIndex:(unsigned)index;

/*!
 *  @method     setEmptyOptionValueAtIndex:
 *  @abstract   (brief description)
 *  @discussion (comprehensive description)
 *  @param      index (description)
 */
- (void) setEmptyOptionValueAtIndex:(unsigned)index;

/*!
 *  @method     setOptionName:atIndex:
 *  @abstract   (brief description)
 *  @discussion (comprehensive description)
 *  @param      name (description)
 *  @param      index (description)
 */
- (void) setOptionName:(NSString *)name atIndex:(unsigned)index;

/*!
 *  @method     setOptionState:atIndex:
 *  @abstract   (brief description)
 *  @discussion (comprehensive description)
 *  @param      flag (description)
 *  @param      index (description)
 */
- (void) setOptionState:(BOOL)flag atIndex:(unsigned)index;

/*!
 *  @method     addOptionNamed:
 *  @abstract   Adds a new option named <i>name</i>, not active, with an empty
 *              value.
 *  @param      name New option name
 */
- (void) addOptionNamed:(NSString *)name;

/*!
 *  @method     addOptionNamed:value:state:
 *  @abstract   Adds a new option, with an value and state.
 *  @discussion Does not disable existing options with same name. Use it only
 *              when option can appear multiple times.
 *  @param      name New option name
 *  @param      value New option value
 *  @param      state New option state
 */
- (void) addOptionNamed:(NSString *)name value:(NSString *)value state:(BOOL)state;

/*!
 *  @method     insertOptionNamed:atIndex:
 *  @abstract   (brief description)
 *  @discussion (comprehensive description)
 *  @param      name (description)
 *  @param      index (description)
 */
- (void) insertOptionNamed:(NSString *)name atIndex:(unsigned)index;

/*!
 *  @method     removeOptionAtIndex:
 *  @abstract   (brief description)
 *  @discussion (comprehensive description)
 *  @param      index (description)
 */
- (void) removeOptionAtIndex:(unsigned)index;

/*!
 *  @method     moveOptionsAtIndexes:toIndex:
 *  @abstract   Reorders options at <i>indexes</i> to new <i>index</i>. Returns
 *              the new index.
 *  @discussion <code>@link saveOptions saveOptions@/link</code> is
 *              automatically called. Returns the index of the first moved 
 *              option.
 *  @param      indexes Array of indexes as <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>
 *              objects
 *  @param      index An index
 */
- (unsigned) moveOptionsAtIndexes:(NSArray *)indexes toIndex:(unsigned)index;


/*!
 *  @methodgroup Getting options
 */

/*!
 *  @method     optionNames
 *  @abstract   Returns all option names, active or not. The same option name
 *              can appear multiple times.
 */
- (NSArray *) optionNames;

/*!
 *  @method     optionValues
 *  @abstract   Returns all option values, active or not.
 *  @discussion There are as many option values as option names returned by 
 *              <code>@link optionNames optionNames@/link</code>.
 */
- (NSArray *) optionValues;

/*!
 *  @method     optionStates
 *  @abstract   Returns all option states as an array of <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>
 *              objects (boolean values).
 *  @discussion There are as many option states as option names returned by
 *              <code>@link optionNames optionNames@/link</code>.
 */
- (NSArray *) optionStates;

/*!
 *  @method     optionValueForName:
 *  @abstract   Returns the option value named <i>name</i>, used by GnuPG.
 *  @discussion In case of multiple occurences of the a named option, returns
 *              the used one. Note that the option might be inactive. Returns 
 *              nil if option is not defined.
 *  @param      name Option name
 */
- (NSString *) optionValueForName:(NSString *)name;

/*!
 *  @method     setOptionValue:forName:
 *  @abstract   (brief description)
 *  @discussion If <i>value</i> is nil, option is removed. You need to call
 *              <code>@link saveOptions saveOptions@/link</code>.
 *  @param      value (description)
 *  @param      name (description)
 */
- (void) setOptionValue:(NSString *)value forName:(NSString *)name;

/*!
 *  @method     setEmptyOptionValueForName:
 *  @abstract   (brief description)
 *  @discussion You need to call <code>@link saveOptions saveOptions@/link</code>.
 *  @param      name (description)
 */
- (void) setEmptyOptionValueForName:(NSString *)name;

/*!
 *  @method     optionStateForName:
 *  @abstract   (brief description)
 *  @discussion (comprehensive description)
 *  @param      name (description)
 */
- (BOOL) optionStateForName:(NSString *)name;

/*!
 *  @method     setOptionState:forName:
 *  @abstract   (brief description)
 *  @discussion If <i>state</i> is <code>YES</code> and option does not yet
 *              exist, it is created. You need to call <code>@link saveOptions saveOptions@/link</code>.
 *  @param      state (description)
 *  @param      name (description)
 */
- (void) setOptionState:(BOOL)state forName:(NSString *)name;


/*!
 *  @methodgroup Sub-options
 */

/*!
 *  @method     subOptionState:forName:
 *  @abstract   Returns sub-option's state, in named option.
 *  @discussion Used for <code>keyserver-options</code> option.
 *  @param      subOptionName Sub-option name
 *  @param      optionName Option name
 */
- (BOOL) subOptionState:(NSString *)subOptionName forName:(NSString *)optionName;

/*!
 *  @method     setSubOption:state:forName:
 *  @abstract   Sets sub-option's state, in named option, and enables option.
 *  @discussion Used for <code>keyserver-options</code> option. If <i>state</i>
 *              is <code>YES</code> and option does not yet exist, it is
 *              created. You need to call <code>@link saveOptions saveOptions@/link</code>.
 *  @param      subOptionName Sub-option name
 *  @param      state Sub-option new state
 *  @param      optionName Option name
 */
- (void) setSubOption:(NSString *)subOptionName state:(BOOL)state forName:(NSString *)optionName;

/*!
 *  @method     subOptionValue:state:forName:
 *  @abstract   Returns sub-option's value and state, in named option.
 *  @discussion Used for <code>keyserver-options</code> option.
 *  @param      subOptionName Sub-option name
 *  @param      statePtr Used to return state; may be NULL
 *  @param      optionName Option name
 */
- (NSString *) subOptionValue:(NSString *)subOptionName state:(BOOL *)statePtr forName:(NSString *)optionName;

/*!
 *  @method     setSubOption:value:state:forName:
 *  @abstract   Sets sub-option's value and state, in named option, and enables
 *              option.
 *  @discussion Used for <code>keyserver-options</code> option. If <i>state</i>
 *              is <code>YES</code> and option does not yet exist, it is
 *              created. You need to call <code>@link saveOptions saveOptions@/link</code>.
 *  @param      subOptionName Sub-option name
 *  @param      value Sub-option new value
 *  @param      state Sub-option new state
 *  @param      optionName Option name
 */
- (void) setSubOption:(NSString *)subOptionName value:(NSString *)value state:(BOOL)state forName:(NSString *)optionName;

/*!
 *  @methodgroup Loading and saving options
 */

/*!
 *  @method     reloadOptions
 *  @abstract   Re-reads GnuPG's configuration file.
 *  @discussion If user changed GnuPG's <i>home directory</i> without logging
 *              out and in, options might be not yet active, and changes won't
 *              be taken in account before logging out and in.
 */
- (void) reloadOptions;

/*!
 *  @method     saveOptions
 *  @abstract   Save options by writing file back.
 *  @discussion If user changed GnuPG's <i>home directory</i> without logging
 *              out and in, new options might be not yet valid.
 */
- (void) saveOptions;


/*!
 *  @methodgroup Getting inactive and active options
 */

/*!
 *  @method     allOptionValuesForName:
 *  @abstract   Returns all values for named option whatever their state is.
 *  @param      name Option name
 */
- (NSArray *) allOptionValuesForName:(NSString *)name;

/*!
 *  @method     activeOptionValuesForName:
 *  @abstract   Returns all values for named option whose state is active.
 *  @discussion First value is the used value, in case no more than one value
 *              is considered by GnuPG.
 *  @param      name Option name
 */
- (NSArray *) activeOptionValuesForName:(NSString *)name;

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGOPTIONS_H */
