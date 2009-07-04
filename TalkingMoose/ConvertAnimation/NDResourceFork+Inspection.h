/* =============================================================================
	PROJECT:	Resurrection II
	FILE:		NDResourceFork+Inspection.h
	PURPOSE:	Category that adds the ability to find out what resources
				are in a file to Nathan Day's NDResourceFork class.
	
	NOTES:		1) API documentation can be found in the source file (.m).
				2) Old Carboneers like me should note that the index you pass
				to get at resources are zero-based, not one-based as those
				you pass to GetIndResource() and the likes. This has been
				done to make it more consistent with the rest of Cocoa, like
				NSArray. We're sorry for the inconvenience.
				In short: they go [0 ... count-1], not [1 ... count].
	
	AUTHOR:		M. Uli Kusterer <witness@zathras.de>, (c) 2003, all rights
				reserved.
	
	REVISIONS:
		2003-05-15	UK	Created.
   ========================================================================== */

/* -----------------------------------------------------------------------------
	Headers:
   -------------------------------------------------------------------------- */

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>
#import "NDResourceFork.h"


/* -----------------------------------------------------------------------------
	Inspection Category:
   -------------------------------------------------------------------------- */

@interface NDResourceFork (Inspection)

// Listing types:
-(short)		countTypes;
-(ResType)		typeAtIndex:(short)zeroBasedIndex;
-(NSString*)	typeStringAtIndex:(short)zeroBasedIndex;	// Same as typeAtIndex, but useful for display purposes.

// Listing resources:
-(short)		countResourcesOfType:(ResType)type;
-(NSData*)		dataForType:(ResType)type AtIndex:(short)zeroBasedIndex;
-(NSString*)	stringForType:(ResType)aType AtIndex:(short)zeroBasedIndex;

// Information about resources:
-(NSString*)	nameForType:(ResType)type AtIndex:(short)zeroBasedIndex;
-(NSString*)	nameForType:(ResType)type Id:(short)resID;
-(short)		idForType:(ResType)type AtIndex:(short)zeroBasedIndex;
-(short)		idForType:(ResType)type Name:(NSString*)resName;
-(long)			sizeForType:(ResType)type AtIndex:(short)zeroBasedIndex;
-(long)			sizeForType:(ResType)type Name:(NSString*)resName;
-(long)			sizeForType:(ResType)type Id:(short)resID;

@end

@interface NDResourceFork (NamedAccess)

-(NSData*)		dataForType:(ResType)type Name:(NSString*)resName;
-(NSString*)	stringForType:(ResType)type Name:(NSString*)resName;

@end

@interface NDResourceFork (MissingStuff)

-(void)			save;
-(Handle)		handleForType:(ResType)type AtIndex:(short)zeroBasedIndex;
-(Handle)		handleForType:(ResType)type Id:(short)resID;
-(Handle)		handleForType:(ResType)type Name:(NSString*)resName;

@end


#if UK_USE_OWN_CONVERSION_CODE
BOOL	NSStringToStr255( NSString* strobj, StringPtr outStr );
#endif /*UK_USE_OWN_CONVERSION_CODE*/
