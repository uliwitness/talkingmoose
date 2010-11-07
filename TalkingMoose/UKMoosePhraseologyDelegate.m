#import "UKMoosePhraseologyDelegate.h"
#import "UKGroupFile.h"

@implementation UKMoosePhraseologyDelegate

int		UKPhraseFileSortFunction( id objA, id objB, void* context )
{
	return [[objA objectForKey: @"name"] caseInsensitiveCompare: [objB objectForKey: @"name"]];
}

-(id)	init
{
	self = [super init];
	if( self )
	{
		phraseFiles = [[NSMutableArray alloc] init];
		
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(applicationDidFinishLaunching:) name: NSApplicationDidFinishLaunchingNotification object: nil];
	}
	
	return self;
}


-(void)	dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self name: NSApplicationDidFinishLaunchingNotification object: nil];

	[phraseFiles release];
	phraseFiles = nil;
	
	[super dealloc];
}


-(void)	applicationDidFinishLaunching: (NSNotification*)notif
{
	[self addFilesFromDirectory: [self phraseFolderPath] withActiveState: YES];
	[self addFilesFromDirectory: [self builtinPhraseFolderPath] withActiveState: YES];
	[self addFilesFromDirectory: [self deactivatedPhraseFolderPath] withActiveState: NO];
	[self addFilesFromDirectory: [self deactivatedBuiltinPhraseFolderPath] withActiveState: NO];
	[phraseFiles sortUsingFunction: UKPhraseFileSortFunction context: nil];
}


-(NSString*)	phraseFolderPath
{
	return[@"~/Library/Application Support/Moose/Phrases/" stringByExpandingTildeInPath];
}


-(NSString*)	deactivatedPhraseFolderPath
{
	return[@"~/Library/Application Support/Moose/Phrases (Off)/" stringByExpandingTildeInPath];
}


-(NSString*)	builtinPhraseFolderPath
{
	return[@"~/Library/Application Support/Moose/Standard Phrases/" stringByExpandingTildeInPath];
}


-(NSString*)	deactivatedBuiltinPhraseFolderPath
{
	return[@"~/Library/Application Support/Moose/Standard Phrases (Off)/" stringByExpandingTildeInPath];
}


-(void)	addFilesFromDirectory: (NSString*)folderPath withActiveState: (BOOL)isActive
{
	NSString*				fname = nil;
	NSNumber*				activeStateObj = [NSNumber numberWithBool: isActive];
	NSDirectoryEnumerator*	enny = [[NSFileManager defaultManager] enumeratorAtPath: folderPath];
	
	if( !enny )
		return;
	
	while(( fname = [enny nextObject] ))
	{
		NSDictionary*	attrs = [enny fileAttributes];
		if( [attrs fileType] != NSFileTypeRegular && [attrs fileType] != NSFileTypeSymbolicLink )
		{
			[enny skipDescendents];
			continue;
		}
		NSString*		pathExt = [[fname pathExtension] lowercaseString];
		if( ![pathExt isEqualToString: @"phrasefile"] && ![pathExt isEqualToString: @"txt"] )
			continue;
		
		NSString*	path = [folderPath stringByAppendingPathComponent: fname];
		
		UKGroupFile*	groupFile = [[[UKGroupFile alloc] initFromGroupFile: path withDefaultCategory: @"PAUSE"] autorelease];
		[groupFile deleteEmptyCategories];
		
		NSMutableDictionary* dict = [NSMutableDictionary dictionary];
		[dict setObject: path forKey: @"path"];
		[dict setObject: fname forKey: @"filename"];
		[dict setObject: [[NSFileManager defaultManager] displayNameAtPath: path] forKey: @"name"];
		[dict setObject: activeStateObj forKey: @"active"];
		[dict setObject: groupFile forKey: @"groupFile"];
		
		[phraseFiles addObject: dict];
	}
}


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	NS_DURING
		if( tableView == phraseFileTable )
		{
			NS_VALUERETURN( [phraseFiles count], int );
		}
		else
			NS_VALUERETURN( 0, int );
	NS_HANDLER
		UKLog(@"Error: %@",localException);
	NS_ENDHANDLER
	return 0;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	NS_DURING
		if( tableView == phraseFileTable )
		{
			if( [[tableColumn identifier] isEqualToString: @"name"] )
				NS_VALUERETURN( [[[phraseFiles objectAtIndex: row] objectForKey: @"name"] stringByDeletingPathExtension], id );
			else
				NS_VALUERETURN( [[phraseFiles objectAtIndex: row] objectForKey: [tableColumn identifier]], id );
		}
		else
			NS_VALUERETURN( @"Gobbledygook? Snarf? Snort.", id );
	NS_HANDLER
		UKLog(@"Error: %@",localException);
	NS_ENDHANDLER
	return @"???";
}


- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	NS_DURING
		if( tableView == phraseFileTable )
		{
			NSString*		ident = [tableColumn identifier];
			NSMutableDictionary*	dict = [phraseFiles objectAtIndex: row];
			
			if( [ident isEqualToString: @"active"] )
			{
				NSString*		oldPath = [dict objectForKey: @"path"];
				NSString*		newPath = nil;
				if( [oldPath rangeOfString: @"Standard Phrases"].length != 0 )
					newPath = [object boolValue] ? [self builtinPhraseFolderPath] : [self deactivatedBuiltinPhraseFolderPath];
				else
					newPath = [object boolValue] ? [self phraseFolderPath] : [self deactivatedPhraseFolderPath];

				if( ![[NSFileManager defaultManager] fileExistsAtPath: newPath] )
					[[NSFileManager defaultManager] createDirectoryAtPath: newPath attributes: nil];
				
				newPath = [newPath stringByAppendingPathComponent: [dict objectForKey: @"filename"]];
				
				//UKLog(@"%@ -> %@", oldPath, newPath);
				
				if( ![[NSFileManager defaultManager] movePath: oldPath toPath: newPath handler: nil] )
					NS_VOIDRETURN;
				else
					[dict setObject: newPath forKey: @"path"];
				
				[dict setObject: object forKey: ident];
			}
		}
	NS_HANDLER
		UKLog(@"Error: %@",localException);
	NS_ENDHANDLER
}


-(void)	tableViewSelectionDidChange: (NSNotification*)notification
{
//	[phraseTable performSelector: @selector(reloadData) withObject: nil afterDelay: 0];
}

-(float)	outlineView: (NSOutlineView*)outlineView heightOfRowByItem: (id)item
{
	if( item == nil )
		return 0;
	else
		return 16;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
//	NS_DURING
//		if( index < 0 )
//			NS_VALUERETURN( @"Huh?", NSString* );
//		if( item == nil )
//		{
//			int	selRow = [phraseFileTable selectedRow];
//			if( selRow < 0 )
//				NS_VALUERETURN( @"HUH???", NSString* );
//			NSMutableDictionary*	dict = [phraseFiles objectAtIndex: selRow];
//			UKGroupFile*			groupFile = [dict objectForKey: @"groupFile"];
//			
//			NS_VALUERETURN( [[[groupFile dictionaryForDisplay] allValues] objectAtIndex: index], id);
//		}
//		else
//			NS_VALUERETURN( [(NSArray*)item objectAtIndex: index], id );
//	NS_HANDLER
//		UKLog(@"Error: %@",localException);
//	NS_ENDHANDLER
	return @"???";
}
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
//	return( item == nil || [item isKindOfClass: [NSArray class]] );
	return NO;
}
- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
//	NS_DURING
//		if( item == nil )
//		{
//			int	selRow = [phraseFileTable selectedRow];
//			if( selRow < 0 )
//				NS_VALUERETURN( 0, int );
//			NSMutableDictionary*	dict = [phraseFiles objectAtIndex: selRow];
//			UKGroupFile*			groupFile = [dict objectForKey: @"groupFile"];
//			NS_VALUERETURN( [[[groupFile dictionaryForDisplay] allValues] count], int );
//		}
//		else
//			NS_VALUERETURN( [(NSArray*)item count], int );
//	NS_HANDLER
//		UKLog(@"Error: %@",localException);
//	NS_ENDHANDLER
	return 0;
}
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
//	NS_DURING
//		if( [item isKindOfClass: [NSString class]] )
//			NS_VALUERETURN( item, id );
//		else
//		{
//			int	selRow = [phraseFileTable selectedRow];
//			if( selRow < 0 )
//				NS_VALUERETURN( @"HUH???", id );
//			NSMutableDictionary*	dict = [phraseFiles objectAtIndex: selRow];
//			UKGroupFile*			groupFile = [dict objectForKey: @"groupFile"];
//			NSArray*				foundKeys = [[groupFile dictionaryForDisplay] allKeysForObject: item];
//			if( [foundKeys count] > 0 )
//				NS_VALUERETURN( [foundKeys objectAtIndex: 0], id );
//			else
//				return @"???";
//		}
//	NS_HANDLER
//		UKLog(@"Error: %@",localException);
//	NS_ENDHANDLER
	return @"???";
}
- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
//	int	selRow = [phraseFileTable selectedRow];
//	if( selRow < 0 )
//		return;
//	NSMutableDictionary*	dict = [phraseFiles objectAtIndex: selRow];
//	UKGroupFile*			groupFile = [dict objectForKey: @"groupFile"];
	
	//[outlineView ];
}


-(BOOL)	outlineView: (NSOutlineView *)outlineView shouldSelectItem: (id)item
{
	return NO;
}


-(BOOL)	outlineView: (NSOutlineView *)outlineView shouldTrackCell: (NSCell *)cell forTableColumn: (NSTableColumn *)tableColumn item: (id)item
{
	return [[tableColumn]];
}

@end
