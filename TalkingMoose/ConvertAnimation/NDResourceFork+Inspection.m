/* =============================================================================
	PROJECT:	Resurrection II
	FILE:		NDResourceFork+Inspection.m
	PURPOSE:	Category that adds the ability to find out what resources
				are in a file to Nathan Day's NDResourceFork class.
	
	NOTES:		Old Carboneers like me should note that the index you pass
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

#import "NDResourceFork+Inspection.h"


@implementation NDResourceFork (Inspection)


/* -----------------------------------------------------------------------------
	countTypes:
		This returns how many different resource types are in the resource
		file. If you wanted to iterate over all resources in a file, you'd
		count the types, then call typeAtIndex: that many times to get all
		ResType type codes, and then for each type, you'd count its resources
		and get the data for each one (or the name, or...).
	
	GIVES:
		short	-	The number of distinct resource types in the file.
					Returns 0 in case of an error, though this is strictly
					spoken a valid return value.
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(short)	countTypes
{
	short		vOldRefNum,
				vResCount = 0;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr == ResError() )
		vResCount = Count1Types();
	if( noErr != ResError() )
		vResCount = 0;

	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return vResCount;
}


/* -----------------------------------------------------------------------------
	typeAtIndex:
		Returns the ResType of the a particular type entry in the resource
		file. Once you have the ResType of a type entry, you can use that
		to determine how many resources of a particular type exist, and
		you can also get at their data.
	
	TAKES:
		zeroBasedIndex	-	A zero-based index < countTypes: that indicates
							which type entry's ResType value you want to
							get.
	
	GIVES:
		ResType			-	The type code (a four-character string stored
							in a long) belonging to the type entry at the
							requested position.
							This returns zero in error conditions (though
							technically that would be a valid return value
							as well).
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(ResType)	typeAtIndex: (short)zeroBasedIndex
{
	short		vOldRefNum;
	ResType		vResType = 0;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr == ResError() )
		Get1IndType( &vResType, zeroBasedIndex +1 );
	if( noErr != ResError() )
		vResType = 0;
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return vResType;
}


/* -----------------------------------------------------------------------------
	typeStringAtIndex:
		Same as stringAtIndex, but returns the ResType as an autoreleased
		string.
		
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(NSString*)	typeStringAtIndex: (short)zeroBasedIndex
{
	ResType		theType = [self typeAtIndex: zeroBasedIndex];
	
	return [NSString stringWithCString: (char*) &theType length:4];
}


/* -----------------------------------------------------------------------------
	countResourcesOfType:
		Returns the number of resources that belong to a particular type.
	
	TAKES:
		type	-	The ResType type code of the resources you wish to count.
	
	GIVES:
		short	-	The number of resources of the requested count in the
					file.
					This returns zero in error conditions (whis is not a
					valid return value, as there is no type entry if there
					are no resources of a particular type).
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(short)	countResourcesOfType:(ResType)type
{
	short		vOldRefNum,
				vResCount = 0;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr == ResError() )
		vResCount = Count1Resources( type );
	if( noErr != ResError() )
		vResCount = 0;
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return vResCount;
}


/* -----------------------------------------------------------------------------
	dataForType:atIndex:
		Returns the data contained a resource specified by its type and its
		index (the howmanyeth resource in the file it is). Note that the index
		is obviously un-stable, and should only be used if you're sure no other
		part of your app is doing write access on it. You should rather use
		a resource's ID if you're not interested in iterating over all
		resources. But you probably knew that already...
	
	TAKES:
		type			-	The ResType type code of the resource whose data
							you wish to retrieve.
		zeroBasedIndex	-	The zero-based index of the resource to get the
							data from, which must be
									index < countResourcesOfType:type
	
	GIVES:
		NSData*			-	The raw binary data of the resource.
							This returns nil in error conditions.
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(NSData*)	dataForType:(ResType)type AtIndex:(short)zeroBasedIndex
{
	NSData*		theData = nil;
	Handle		vResHandle;
	short		vOldRefNum;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr ==  ResError( ) )
	{
		vResHandle = Get1IndResource( type, zeroBasedIndex +1 );

		if( vResHandle && noErr ==  ResError( ) )
		{
			HLock( vResHandle );
			theData = [NSData dataWithBytes:*vResHandle length:GetHandleSize( vResHandle )];
			HUnlock( vResHandle );
		}
		
		if( vResHandle )
			ReleaseResource( vResHandle );
	}
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return theData;
}


/* -----------------------------------------------------------------------------
	nameForType:atIndex:
		Returns the name of a resource at a particular index.
	
	GIVES:
		NSString*	-	The name of the resource.
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(NSString*)	nameForType:(ResType)type AtIndex:(short)zeroBasedIndex
{
	NSString*	theName = nil;
	Handle		vResHandle;
	short		vOldRefNum,
				vResID;
	ResType		vResType;
	Str255		vResName;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr ==  ResError() )
	{
		SetResLoad( false );
		vResHandle = Get1IndResource( type, zeroBasedIndex +1 );
		SetResLoad( true );

		if( vResHandle && noErr == ResError() )
		{
			GetResInfo( vResHandle, &vResID, &vResType, vResName );
			if( noErr == ResError() )
			{
				theName = (NSString*) CFStringCreateWithPascalString( kCFAllocatorDefault, vResName, kCFStringEncodingMacRoman );
				[theName autorelease];
			}
		}
	}
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return theName;
}


/* -----------------------------------------------------------------------------
	sizeForType:atIndex:
		Returns the size of the data of a resource at a particular index.
	
	GIVES:
		long	-	The size of the resource's data in bytes.
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(long)	sizeForType:(ResType)type AtIndex:(short)zeroBasedIndex
{
	Handle		vResHandle;
	short		vOldRefNum;
	long		vResSize;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr ==  ResError() )
	{
		SetResLoad( false );
		vResHandle = Get1IndResource( type, zeroBasedIndex +1 );
		SetResLoad( true );

		if( vResHandle && noErr == ResError() )
		{
			vResSize = GetResourceSizeOnDisk( vResHandle );
			if( noErr != ResError() )
				vResSize = 0;
		}
	}
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return vResSize;
}


/* -----------------------------------------------------------------------------
	sizeForType:Id:
		Returns the size of the data of a resource of specified ID and type.
	
	GIVES:
		long	-	The size of the resource's data in bytes.
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(long)	sizeForType:(ResType)type Id:(short)resID
{
	Handle		vResHandle;
	short		vOldRefNum;
	long		vResSize;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr ==  ResError() )
	{
		SetResLoad( false );
		vResHandle = Get1Resource( type, resID );
		SetResLoad( true );

		if( vResHandle && noErr == ResError() )
		{
			vResSize = GetResourceSizeOnDisk( vResHandle );
			if( noErr != ResError() )
				vResSize = 0;
		}
	}
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return vResSize;
}


/* -----------------------------------------------------------------------------
	sizeForType:Name:
		Returns the size of the data of a resource of specified name and type.
	
	GIVES:
		long	-	The size of the resource's data in bytes.
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(long)	sizeForType:(ResType)type Name:(NSString*)resName
{
	Handle		vResHandle;
	short		vOldRefNum;
	long		vResSize;
	Str255		vResName;
	
	if( !NSStringToStr255( resName, vResName ) )
		return 0;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr ==  ResError() )
	{
		SetResLoad( false );
		vResHandle = Get1NamedResource( type, vResName );
		SetResLoad( true );

		if( vResHandle && noErr == ResError() )
		{
			vResSize = GetResourceSizeOnDisk( vResHandle );
			if( noErr != ResError() )
				vResSize = 0;
		}
	}
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return vResSize;
}


/* -----------------------------------------------------------------------------
	nameForType:Id:
		Returns the name of a resource with the specified type and ID.
	
	GIVES:
		NSString*	-	The name of the resource.
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(NSString*)	nameForType:(ResType)type Id:(short)resID
{
	NSString*	theName = nil;
	Handle		vResHandle;
	short		vOldRefNum,
				vResID;
	ResType		vResType;
	Str255		vResName;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr ==  ResError() )
	{
		SetResLoad( false );
		vResHandle = Get1Resource( type, resID );
		SetResLoad( true );

		if( vResHandle && noErr == ResError() )
		{
			GetResInfo( vResHandle, &vResID, &vResType, vResName );
			if( noErr == ResError() )
			{
				theName = (NSString*) CFStringCreateWithPascalString( kCFAllocatorDefault, vResName, kCFStringEncodingMacRoman );
				[theName autorelease];
			}
		}
	}
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return theName;
}


/* -----------------------------------------------------------------------------
	idForType:atIndex:
		Returns the resource ID of a resource at a particular index.
	
	GIVES:
		short	-	The resource ID of the resource.
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(short)		idForType:(ResType)type AtIndex:(short)zeroBasedIndex
{
	Handle		vResHandle;
	short		vOldRefNum,
				vResID = 0;
	ResType		vResType;
	Str255		vResName;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr ==  ResError() )
	{
		SetResLoad( false );
		vResHandle = Get1IndResource( type, zeroBasedIndex +1 );
		SetResLoad( true );

		if( vResHandle && noErr == ResError() )
			GetResInfo( vResHandle, &vResID, &vResType, vResName );
	}
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return vResID;
}


/* -----------------------------------------------------------------------------
	idForType:Name:
		Returns the ID of a resource with a particular name.
	
	GIVES:
		short	-	The resource ID of the resource.
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(short)		idForType:(ResType)type Name:(NSString*)resName
{
	Handle		vResHandle;
	short		vOldRefNum,
				vResID = 0;
	ResType		vResType;
	Str255		vResName;
	
	if( !NSStringToStr255( resName, vResName ) )
		return 0;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr ==  ResError() )
	{
		SetResLoad( false );
		vResHandle = Get1NamedResource( type, vResName );
		SetResLoad( true );

		if( vResHandle && noErr == ResError() )
			GetResInfo( vResHandle, &vResID, &vResType, vResName );
	}
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return vResID;
}


/* -----------------------------------------------------------------------------
	stringForType:AtIndex:
		Returns the data of a string resource at a particular index.
	
	GIVES:
		NSString*	-	The data contained in the string.
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(NSString*)	stringForType:(ResType)aType AtIndex:(short)zeroBasedIndex
{
	NSData*			theData;
	unsigned char	len;

	theData = [self dataForType: aType AtIndex: (zeroBasedIndex +1)];

	[theData getBytes:&len length:1];	// Read length byte.
	theData = [theData subdataWithRange:NSMakeRange(1,len)];
	
	return [[[NSString alloc]initWithData:theData encoding:NSMacOSRomanStringEncoding] autorelease];
}




@end

@implementation NDResourceFork (NamedAccess)

/* -----------------------------------------------------------------------------
	dataForType:Name:
		Returns the data of a resource of the specified name and type.
	
	GIVES:
		NSString*	-	The data contained in the resource.
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(NSData*)		dataForType:(ResType)type Name:(NSString*)resName
{
	NSData*		theData = nil;
	Handle		vResHandle;
	short		vOldRefNum;
	Str255		vResName;

	if( !NSStringToStr255( resName, vResName ) )
		return nil;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr ==  ResError( ) )
	{
		vResHandle = Get1NamedResource( type, vResName );

		if( vResHandle && noErr ==  ResError() )
		{
			HLock( vResHandle );
			theData = [NSData dataWithBytes:*vResHandle length:GetHandleSize( vResHandle )];
			HUnlock( vResHandle );
		}
		
		if( vResHandle )
			ReleaseResource( vResHandle );
	}
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return theData;
}


/* -----------------------------------------------------------------------------
	stringForType:Name:
		Returns the data of a resource of the specified name and type as a
		string.
	
	GIVES:
		NSString*	-	The data contained in the resource as a string.
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

-(NSString*)	stringForType:(ResType)type Name:(NSString*)resName
{
	NSData*			theData;
	unsigned char	len;

	theData = [self dataForType: type Name: resName];

	[theData getBytes:&len length:1];	// Read length byte.
	theData = [theData subdataWithRange:NSMakeRange(1,len)];
	
	return [[[NSString alloc]initWithData:theData encoding:NSMacOSRomanStringEncoding] autorelease];
}


@end


@implementation NDResourceFork (MissingStuff)

-(void)		save
{
	UpdateResFile( fileReference );
}

-(Handle)	handleForType:(ResType)type AtIndex:(short)zeroBasedIndex
{
	Handle		vResHandle = NULL;
	short		vOldRefNum;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr == ResError() )
	{
		vResHandle = Get1IndResource( type, zeroBasedIndex +1 );

		if( noErr != ResError( ) )
			vResHandle = NULL;
	}
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return vResHandle;
}

-(Handle)	handleForType:(ResType)type Id:(short)resID
{
	Handle		vResHandle = NULL;
	short		vOldRefNum;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr == ResError( ) )
	{
		vResHandle = Get1Resource( type, resID );

		if( noErr != ResError( ) )
			vResHandle = NULL;
	}
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return vResHandle;
}

-(Handle)		handleForType:(ResType)type Name:(NSString*)resName
{
	Handle		vResHandle = NULL;
	short		vOldRefNum;
	Str255		vResName;

	if( !NSStringToStr255( resName, vResName ) )
		return nil;

	vOldRefNum = CurResFile();		// Save current res map's refNum so we can restore it and not mess up everything.
	UseResFile( fileReference );	// Make our resource map current.

	if( noErr == ResError( ) )
	{
		vResHandle = Get1NamedResource( type, vResName );

		if( noErr != ResError() )
			vResHandle = NULL;
	}
	
	UseResFile( vOldRefNum );		// Make current previous resource map.
	
	return vResHandle;
}

@end


#if UK_USE_OWN_CONVERSION_CODE
/* -----------------------------------------------------------------------------
	NSStringToStr255:
		Converts an NSString to a MacRoman-encoded Pascal string.
	
	TAKES:
		strobj		-	The string to be converted.
		outStr		-	A pointer to a Str255 to hold the converted string.
	
	GIVES:
		BOOL		-	YES on success, NO if the string contained characters
						unsupported by MacRoman or if the string was too long.
		outStr		-	This Str255 is set to the equivalent of the NSString.
	
	REVISIONS:
		2003-05-15	UK	Created.
   -------------------------------------------------------------------------- */

BOOL	NSStringToStr255( NSString* strobj, StringPtr outStr )
{
	if( [strobj length] < 256 )
	{
		Boolean		result = false;
		
		result = CFStringGetPascalString( (CFStringRef) strobj, outStr, 256, kCFStringEncodingMacRoman );
		
		return( result == true );
	}
	else
		return NO;
}

#endif /*UK_USE_OWN_CONVERSION_CODE*/
