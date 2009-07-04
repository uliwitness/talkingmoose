//
//  UKMooseAppDelegate.h
//  CocoaMoose
//
//  Created by Uli Kusterer on Mon Apr 05 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import <Foundation/Foundation.h>


@class  UKMooseController;
@class  UKPhraseDatabase;
@class  UKSpeechSynthesizer;
@class  UKSpeechSettingsView;
@class  UKIdleTimer;
@class  PTHotKey;


@interface UKMooseAppDelegate : NSObject
{
	IBOutlet NSTableView*		mooseList;			// List view for displaying available mooses.
	IBOutlet NSImageView*		imageView;			// Image view where current moose is displayed.
	IBOutlet UKPhraseDatabase*  phraseDB;			// All phrases.
	IBOutlet UKSpeechSettingsView*  speechSets;		// Prefs GUI for speech channel.
	IBOutlet NSColorWell*		startColor;			// Start color for gradient or solid color.
	IBOutlet NSColorWell*		endColor;			// End color for gradient.
	IBOutlet NSPopUpButton*		imagePopup;			// Pop-up of images available as backgrounds.
	NSMutableArray*				mooseControllers;   // List of all available moose controllers.
	UKMooseController*			currentMoose;		// Moose controller currently in use.
	UKSpeechSynthesizer*		speechSynth;		// The synthesizer the current moose is lip-syncing with.
	UKIdleTimer*				phraseTimer;		// Timer that calls us whenever a new phrase should be spoken.
	IBOutlet NSTextField*		speakNowHKField;
	PTHotKey*					speakNowHotkey;			// Global "speak random phrase" shortcut.
	IBOutlet NSTextField*		repeatLastPhraseHKField;
	PTHotKey*					repeatLastPhraseHotkey; // Global "repeat last phrase" hotkey.
	IBOutlet NSTextField*		silenceMooseHKField;
	PTHotKey*					silenceMooseHotkey;		// Global "shut up, moose!" hotkey.
	int							mooseDisableCount;		// If zero, moose may speak, if > 0, moose should stay quiet.
	BOOL						terminateWhenFinished;  // Set to YES to quit after "goodbye" speech has finished.
	IBOutlet NSSlider*			speechDelaySlider;		// Slider for controlling how often to speak.
	IBOutlet NSTextField*		speechDelayField;		// Field displaying delay as a number.
	IBOutlet NSButton*			launchAtLoginSwitch;	// Checkbox whether to launch Moose at Login.
	IBOutlet NSButton*			shutUpSwitch;			// Checkbox whether Moose is to abstain from speaking right now.
	IBOutlet NSTextView*		speechBubbleView;		// Display text being spoken here.
	BOOL						showSpokenString;		// Display text being spoken?
	IBOutlet NSButton*			showSpokenStringSwitch; // Checkbox for turning on/off showing of spoken string.
}

-(void) mooseControllerAnimationDidChange: (UKMooseController*)controller;
-(void) mooseControllerDidChange;

-(void) speakPhraseFromGroup: (NSString*)group;
-(void) speakOnePhrase: (id)sender;
-(void) repeatLastPhrase: (id)sender;
-(void) silenceMoose: (id)sender;

-(void) backgroundImageDidChange: (id)sender;
-(void) takeStartColorFrom: (id)sender;
-(void) takeEndColorFrom: (id)sender;
-(void) mooseImageClicked: (id)sender;
-(void) takeSpeechDelayFrom: (id)sender;
-(void) takeLaunchAtLoginBoolFrom: (id)sender;
-(void) takeShowSpokenStringBoolFrom: (id)sender;

-(void) changeSpeakOnePhraseHotkey: (id)sender;
-(void) changeRepeatLastPhraseHotkey: (id)sender;
-(void) changeSilenceMooseHotkey: (id)sender;

-(int) loadAnimationsInFolder: (NSString*)folder;

-(void) volumeMountNotification:(NSNotification*)notif;
-(void) volumeUnmountNotification:(NSNotification*)notif;
-(void) applicationLaunchNotification:(NSNotification*)notif;
-(void) applicationTerminationNotification:(NSNotification*)notif;

@end


#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_3

#define NSWorkspaceSessionDidBecomeActiveNotification   @"NSWorkspaceSessionDidBecomeActive"
#define NSWorkspaceSessionDidResignActiveNotification   @"NSWorkspaceSessionDidResignActive"

#endif
