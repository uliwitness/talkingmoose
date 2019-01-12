//
//  UKMooseAppDelegate.h
//  CocoaMoose
//
//  Created by Uli Kusterer on Mon Apr 05 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UKApplicationListController.h"


@class  UKMooseController;
@class  UKPhraseDatabase;
@class  UKSpeechSettingsView;
@class  PTHotKey;
@class  UKCarbonEventHandler;
@class  UKMooseDragAreaView;
@class	UKRecordedSpeechChannel;
@class	UKClickableImageView;


@interface UKMooseAppDelegate : NSObject
{
	IBOutlet NSTableView*					mooseList;				// List view for displaying available mooses.
	IBOutlet UKPhraseDatabase*				phraseDB;				// All phrases.
	IBOutlet UKSpeechSettingsView*			speechSets;				// Prefs GUI for speech channel.
	NSMutableArray*							mooseControllers;		// List of all available moose controllers.
	UKMooseController*						currentMoose;			// Moose controller currently in use.
	IBOutlet NSTextField*					speakNowHKField;
	PTHotKey*								speakNowHotkey;			// Global "speak random phrase" shortcut.
	IBOutlet NSTextField*					repeatLastPhraseHKField;
	PTHotKey*								repeatLastPhraseHotkey; // Global "repeat last phrase" hotkey.
	IBOutlet NSTextField*					silenceMooseHKField;
	PTHotKey*								silenceMooseHotkey;		// Global "shut up, moose!" hotkey.
	IBOutlet NSSlider*						speechDelaySlider;		// Slider for controlling how often to speak.
	IBOutlet NSTextField*					speechDelayField;		// Field displaying delay as a number.
	IBOutlet NSButton*						launchAtLoginSwitch;	// Checkbox whether to launch Moose at Login.
	IBOutlet NSButton*						shutUpSwitch;			// Checkbox whether Moose is to abstain from speaking right now.
	BOOL									showSpokenString;		// Display text being spoken?
	IBOutlet NSButton*						showSpokenStringSwitch; // Checkbox for turning on/off showing of spoken string.
	IBOutlet NSButton*						speakHoursSwitch;       // Checkbox for turning on/off speaking time on full hours.
	IBOutlet NSButton*						speakHalfHoursSwitch;   // Checkbox for turning on/off speaking time on half hours.
	IBOutlet NSButton*						beAnallyRetentive;      // Checkbox for removing the inexactitude from full/half hour announcements.
    float									scaleFactor;            // By how much the current moose animation window should be enlarged/made smaller.
	IBOutlet UKApplicationListController*	excludeApps;			// List of apps that cause the Moose to go quiet.
	IBOutlet NSWindow*						settingsWindow;			// The settings window.
	BOOL									speakOnVolumeMount;
	IBOutlet NSButton*						speakOnVolMountSwitch;
	BOOL									speakOnAppLaunchQuit;
	IBOutlet NSButton*						speakOnAppLaunchQuitSwitch;
	BOOL									speakOnAppChange;
	IBOutlet NSButton*						speakOnAppChangeSwitch;
	UKCarbonEventHandler*					appSwitchEventHandler;
	IBOutlet NSTabView*						mainTabView;
	IBOutlet NSPanel*						secretAboutBox;
	NSXPCConnection							*_connectionToService;
}

@property (assign) IBOutlet NSProgressIndicator *launchProgressSpinner;

-(IBAction)	orderFrontSecretAboutBox: (id)sender;

-(void) mooseControllerDidChange;

-(void) toggleSpeakHours: (id)sender;
-(void) toggleSpeakHalfHours: (id)sender;
-(void) toggleAnallyRetentive: (id)sender;
-(void) toggleSpeakVolumeMount: (id)sender;
-(void) toggleSpeakAppLaunchQuit: (id)sender;
-(void) toggleSpeakAppChange: (id)sender;

// Factored out stuff from awakeFromNib:
-(void)	loadMooseControllers;
-(void)	loadSettingsFromDefaultsIntoUI;

// Menu item actions:
-(void)	moosePictClicked: (id)sender;

-(void) takeSpeechDelayFrom: (id)sender;
-(void) takeLaunchAtLoginBoolFrom: (id)sender;
-(void) takeShowSpokenStringBoolFrom: (id)sender;

-(void) changeSpeakOnePhraseHotkey: (id)sender;
-(void) changeRepeatLastPhraseHotkey: (id)sender;
-(void) changeSilenceMooseHotkey: (id)sender;

-(void) loadAnimationsInFolder: (NSString*)folder;
-(UKMooseController*) loadAnimationAtPath: (NSString*)animationPath andReload: (BOOL)reloadList;

-(void) volumeMountNotification:(NSNotification*)notif;
-(void) volumeUnmountNotification:(NSNotification*)notif;
-(void) applicationLaunchNotification:(NSNotification*)notif;
-(void) applicationTerminationNotification:(NSNotification*)notif;

-(void) setMooseSilenced: (BOOL)doSilence;
-(BOOL) mooseSilenced;
-(void) refreshShutUpBadge;
-(void) refreshSpeakHoursUI;

-(BOOL)	application: (NSApplication*)sender openFile: (NSString*)filename dontAskButAddToList: (NSMutableArray*)arr;

@end


#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_3

#define NSWorkspaceSessionDidBecomeActiveNotification   @"NSWorkspaceSessionDidBecomeActive"
#define NSWorkspaceSessionDidResignActiveNotification   @"NSWorkspaceSessionDidResignActive"

#endif
