//
//  iPhroxyAppDelegate.m
//  iPhroxy
//
//  Created by Uli Kusterer on 17.11.08.
//  Copyright The Void Software 2008. All rights reserved.
//

#import "iPhroxyViewController.h"
#import <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <ifaddrs.h>
#include <net/if.h>


struct in_addr	UKGetMyIPAddress()
{
	struct	in_addr		returnAddress = { 0 };
	struct ifaddrs		*ifaddr, *ifaddrs;
	if (getifaddrs(&ifaddrs) != 0)
	{
		NSLog(@"getifaddrs failed");
		return returnAddress;
	}
	ifaddr = ifaddrs;
	while (ifaddr != NULL)
	{
		if (!(ifaddr->ifa_flags & IFF_UP))
		{
			//NSLog(@"one not up.");
			ifaddr = ifaddr->ifa_next;
			continue;
		}
		if (ifaddr->ifa_flags & IFF_LOOPBACK)
		{
			//NSLog(@"loopback.");
			ifaddr = ifaddr->ifa_next;
			continue;
		}
		if (ifaddr->ifa_addr->sa_family != AF_INET)
		{
			//NSLog(@"IPv6 or something similarly weird.");
			ifaddr = ifaddr->ifa_next;
			continue;
		}
		struct sockaddr_in *sin_addr = (struct sockaddr_in *)ifaddr->ifa_addr;
		//NSLog( @"%s", inet_ntoa( sin_addr->sin_addr ) );
		returnAddress = sin_addr->sin_addr;
		ifaddr = ifaddr->ifa_next;
		break;
	}
	freeifaddrs(ifaddrs);
	
	return returnAddress;
}


@implementation iPhroxyViewController

@synthesize portNumField;
@synthesize fileHandle;


/*
 Implement loadView if you want to create a view hierarchy programmatically
- (void)loadView {
}
 */

// Implement viewDidLoad if you need to do additional setup after loading the view.
- (void)viewDidLoad
{
	[super viewDidLoad];
	
	[self startProxyServer];
}


-(void)	startProxyServer
{
	unsigned short	portNumber = 0;
	int				socketFD = socket( AF_INET, SOCK_STREAM, 0 );
	if( socketFD < 0 )
	{
		NSLog( @"Couldn't create socket." );
		return;
	}
	
	struct sockaddr_in	peer;
	struct sockaddr_in	addrIn;
	
	peer.sin_family = AF_INET;
	peer.sin_port = htons(0);
	peer.sin_addr.s_addr = htonl(INADDR_ANY);
	int	bindResult = bind( socketFD, (struct sockaddr *)&peer, sizeof(peer) );
	if( bindResult < 0 )
	{
		close( socketFD );
		socketFD = -1;
		NSLog(@"couldn't bind");
		return;
	}
	int listenResult = listen( socketFD, 3 );
	if( listenResult < 0 )
	{
		close( socketFD );
		socketFD = -1;
		NSLog(@"couldn't listen");
		return;
	}
	
	socklen_t		sockaddr_size = sizeof(addrIn);
	if( getsockname( socketFD, (struct sockaddr*)&addrIn, &sockaddr_size ) == 0 )
		portNumber = ntohs( addrIn.sin_port );
	
	self.fileHandle = [[[NSFileHandle alloc] initWithFileDescriptor: socketFD closeOnDealloc: YES] autorelease];
	[fileHandle acceptConnectionInBackgroundAndNotify];
		
	struct in_addr	myAddress = UKGetMyIPAddress();
	
	NSString*	addr = [NSString stringWithFormat: @"%s:%u", inet_ntoa(myAddress), portNumber];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
      [nc addObserver: self
             selector: @selector(fileHandleReceivedReqestForNewConnection:)
                 name: NSFileHandleConnectionAcceptedNotification
               object: self.fileHandle];
	
	[self.portNumField setText: addr];
}


-(void)	fileHandleReceivedReqestForNewConnection: (NSNotification*)notif
{
	NSFileHandle*	listenerFH = [notif object];
	NSFileHandle*	fh = [[notif userInfo] objectForKey: NSFileHandleNotificationFileHandleItem];
	NSNumber *		errorNb = [[notif userInfo] objectForKey:@"NSFileHandleError"];
	if( errorNb )
	{
		UKLog( @"NSFileHandle Error: %@", errorNb );
		return;
	}
	
	[listenerFH acceptConnectionInBackgroundAndNotify];	// Continue listening for more requests.
	
	// Create a new object that will now take care of handling this connection:
	[NSThread detachNewThreadSelector: @selector(keepForwardingFromFileHandle:) toTarget: self withObject: fh];
}


-(void)	keepForwardingFromFileHandle: (NSFileHandle*)fh
{
	unsigned char		version = 0;
	read( [fh fileDescriptor], &version, 1 );
	if( version == 0x04 )
	{
		// Command to execute:
		unsigned char		commandCode = 0;
		read( [fh fileDescriptor], &commandCode, 1 );
		
		// Port to connect at:
		unsigned short		portNumber = 0;
		read( [fh fileDescriptor], &portNumber, 2 );
		portNumber = portNumber;
		
		// Address to connect to:
		in_addr_t		addr = 0;
		read( [fh fileDescriptor], &addr, 4 );
		
		// User ID (ignored):
		char		currCh = 'U';
		while( currCh != 0 )
			read( [fh fileDescriptor], &currCh, 1 );
		
		if( commandCode == 0x01 )	// Stream connection.
		{
			
		}
		else if( commandCode == 0x02 )	// Port binding.
		{
			// +++ For FTP.
		}
	}
	
	[fh closeFile];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}


- (void)dealloc {
	[super dealloc];
}

@end
