/* UKMoosePhraseologyDelegate */

#import <Cocoa/Cocoa.h>

@interface UKMoosePhraseologyDelegate : NSObject
{
    IBOutlet NSTableView	*phraseFileTable;
    IBOutlet NSOutlineView	*phraseTable;
	NSMutableArray			*phraseFiles;
}

-(void)			addFilesFromDirectory: (NSString*)folderPath withActiveState: (BOOL)isActive;
-(NSString*)	phraseFolderPath;
-(NSString*)	deactivatedPhraseFolderPath;
-(NSString*)	builtinPhraseFolderPath;
-(NSString*)	deactivatedBuiltinPhraseFolderPath;

-(void)			applicationDidFinishLaunching: (NSNotification*)notif;
@end
