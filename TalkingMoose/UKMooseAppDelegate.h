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
@class  UKIdleTimer;
@class  PTHotKey;
@class  UKCarbonEventHandler;
@class  UKMooseDragAreaView;
@class	UKRecordedSpeechChannel;


@interface UKMooseAppDelegate : NSObject
{
	IBOutlet NSImageView*					imageView;				// Image view where current moose is displayed.
    IBOutlet NSView*						windowWidgets;			// Close box, zoom box and grow box that we hide when mouse enters our window.
	IBOutlet NSTableView*					mooseList;				// List view for displaying available mooses.
	IBOutlet UKPhraseDatabase*				phraseDB;				// All phrases.
	IBOutlet UKSpeechSettingsView*			speechSets;				// Prefs GUI for speech channel.
	IBOutlet NSColorWell*					startColor;				// Start color for gradient or solid color.
	IBOutlet NSColorWell*					endColor;				// End color for gradient.
	IBOutlet NSPopUpButton*					imagePopup;				// Pop-up of images available as backgrounds.
	NSMutableArray*							mooseControllers;		// List of all available moose controllers.
	UKMooseController*						currentMoose;			// Moose controller currently in use.
	NSSpeechSynthesizer*					speechSynth;			// The synthesizer the current moose is lip-syncing with.
	UKIdleTimer*							phraseTimer;			// Timer that calls us whenever a new phrase should be spoken.
	IBOutlet NSTextField*					speakNowHKField;
	PTHotKey*								speakNowHotkey;			// Global "speak random phrase" shortcut.
	IBOutlet NSTextField*					repeatLastPhraseHKField;
	PTHotKey*								repeatLastPhraseHotkey; // Global "repeat last phrase" hotkey.
	IBOutlet NSTextField*					silenceMooseHKField;
	PTHotKey*								silenceMooseHotkey;		// Global "shut up, moose!" hotkey.
	int										mooseDisableCount;		// If zero, moose may speak, if > 0, moose should stay quiet.
	BOOL									terminateWhenFinished;  // Set to YES to quit after "goodbye" speech has finished.
	IBOutlet NSSlider*						speechDelaySlider;		// Slider for controlling how often to speak.
	IBOutlet NSTextField*					speechDelayField;		// Field displaying delay as a number.
	IBOutlet NSButton*						launchAtLoginSwitch;	// Checkbox whether to launch Moose at Login.
	IBOutlet NSButton*						shutUpSwitch;			// Checkbox whether Moose is to abstain from speaking right now.
	IBOutlet NSTextView*					speechBubbleView;		// Display text being spoken here.
	BOOL									showSpokenString;		// Display text being spoken?
	IBOutlet NSButton*						showSpokenStringSwitch; // Checkbox for turning on/off showing of spoken string.
    int										mooseVisibleCount;      // Visible-counter for showMoose/hideMoose. Moose window is hidden only when this becomes 0.
    NSTimer*								clockTimer;             // Timer that's set to fire on full/half hours.
	IBOutlet NSButton*						speakHoursSwitch;       // Checkbox for turning on/off speaking time on full hours.
	IBOutlet NSButton*						speakHalfHoursSwitch;   // Checkbox for turning on/off speaking time on half hours.
	IBOutlet NSButton*						beAnallyRetentive;      // Checkbox for removing the inexactitude from full/half hour announcements.
	IBOutlet NSButton*						fadeInOutSwitch;        // Checkbox for activating fade in/fade out for Moose window.
    float									scaleFactor;            // By how much the current moose animation window should be enlarged/made smaller.
    BOOL									fadeInOut;              // state of fade in/out checkbox.
	IBOutlet UKApplicationListController*	excludeApps;			// List of apps that cause the Moose to go quiet.
	IBOutlet NSWindow*						settingsWindow;			// The settings window.
	NSView*									windowWidgetsSuperview;	// View to reinsert windowWidgets in again to show it on 10.2.
	IBOutlet NSButton*						animateInDockSwitch;	// Checkbox whether Moose is to keep linking and glancing when not speaking.
	BOOL									speakOnVolumeMount;
	IBOutlet NSButton*						speakOnVolMountSwitch;
	BOOL									speakOnAppLaunchQuit;
	IBOutlet NSButton*						speakOnAppLaunchQuitSwitch;
	BOOL									speakOnAppChange;
	IBOutlet NSButton*						speakOnAppChangeSwitch;
	UKCarbonEventHandler*					appSwitchEventHandler;
	IBOutlet NSTextField*					startColorLabel;
	IBOutlet NSTextField*					endColorLabel;
	IBOutlet UKMooseDragAreaView*			dragArea;
	BOOL									didSetDragAreaCursor;
	IBOutlet NSTabView*						mainTabView;
	UKRecordedSpeechChannel*				recSpeechSynth;
}

-(void) mooseControllerAnimationDidChange: (UKMooseController*)controller;
-(void) mooseControllerDidChange;

-(BOOL) speakPhraseFromGroup: (NSString*)group;
-(BOOL) speakPhraseFromGroup: (NSString*)group withFillerString: (NSString*)fill;
-(void)	speakPhraseOnMainThreadFromGroup: (NSString*)grp withFillerString:(NSString*)fill;
-(void)	speakPhraseFromDictionary: (NSDictionary*)dict;
-(BOOL) speakOnePhrase: (id)sender;
-(void) speakString: (NSString*)currPhrase;
-(void) repeatLastPhrase: (id)sender;
-(void) silenceMoose: (id)sender;
-(void) toggleSpeakHours: (id)sender;
-(void) toggleSpeakHalfHours: (id)sender;
-(void) toggleAnallyRetentive: (id)sender;
-(void) toggleFadeInOut: (id)sender;
-(void) takeAnimateInDockBoolFrom: (id)sender;
-(void) toggleSpeakVolumeMount: (id)sender;
-(void) toggleSpeakAppLaunchQuit: (id)sender;
-(void) toggleSpeakAppChange: (id)sender;

// Factored out stuff from awakeFromNib:
-(void)	loadMooseControllers;
-(void)	loadSettingsFromDefaultsIntoUI;
-(void)	setUpSpeechBubbleWindow;

// Nestable show/hide methods that make sure moose window doesn't hide until
//	everyone that needs it visible has signed off:
-(void) showMoose;
-(void) hideMoose;

// Menu item actions:
-(void)	showSettingsWindow: (id)sender;

// Window widget actions:
-(void) mooseAnimationWindowClicked: (id)sender;
-(void) resizeMoose: (id)sender;
-(void) zoomMoose: (id)sender;

-(void)	moosePictClicked: (id)sender;

-(void) backgroundImageDidChange: (id)sender;
-(void) takeStartColorFrom: (id)sender;
-(void) takeEndColorFrom: (id)sender;
-(void) dragMooseAnimationWindow: (id)sender;
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
-(void) showSpeechBubbleWithString: (NSString*)currPhrase;
-(void) updateClockTimerFireTime: (NSTimer*)timer;
-(void) halfHourElapsed: (NSTimer*)timer;
-(void) refreshSpeakHoursUI;

-(void)		setScaleFactor: (float)sf;
-(float)	scaleFactor;

-(BOOL)	application: (NSApplication*)sender openFile: (NSString*)filename dontAskButAddToList: (NSMutableArray*)arr;

-(void)	pinWidgetsBoxToBotRight;

@end


#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_3

#define NSWorkspaceSessionDidBecomeActiveNotification   @"NSWorkspaceSessionDidBecomeActive"
#define NSWorkspaceSessionDidResignActiveNotification   @"NSWorkspaceSessionDidResignActive"

#endif
