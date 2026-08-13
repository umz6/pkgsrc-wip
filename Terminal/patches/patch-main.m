Fix duplicate window when launched with a program argument: run the
argument through /bin/sh -c and set a flag so applicationDidFinishLaunching:
does not create a second window.

Call setlocale(LC_CTYPE, "") in main() so wcwidth(3) returns correct
widths for non-ASCII characters (required by TerminalView.m).  Only
LC_CTYPE is set, not LC_ALL, so keyboard escape-sequence handling is
unaffected.

--- main.m.orig
+++ main.m
@@ -49,6 +49,8 @@
 #import <GNUstepGUI/GSHbox.h>
 #import "Label.h"
 
+#include <locale.h>
+
 
 #import "PreferencesWindowController.h"
 #import "Services.h"
@@ -88,6 +90,11 @@
 
 @implementation Terminal
 
+/* Set when application:openFile: handled a command-line argument during
+   launch, so applicationDidFinishLaunching: does not create a duplicate
+   window for the same argument. */
+static BOOL didOpenFileAtLaunch = NO;
+
 - init
 {
 	if (!(self=[super init])) return nil;
@@ -307,6 +314,11 @@
 
 	[NSApp setServicesProvider: [[TerminalServices alloc] init]];
 
+	/* If a command-line argument was already handled by application:openFile:
+	   during launch, do not create a duplicate window for it. */
+	if (didOpenFileAtLaunch)
+		return;
+
 	if ([args count]>1)
 	{
 		TerminalWindowController *twc;
@@ -475,9 +487,13 @@
 	/* TODO: shouldn't ignore other apps */
 	[NSApp activateIgnoringOtherApps: YES];
 
+	/* A command-line argument (e.g. "emacs -nw") is passed here as a single
+	   string; run it through the shell so it is interpreted as a command
+	   line rather than a single program path. */
+	didOpenFileAtLaunch = YES;
 	twc=[TerminalWindowController newTerminalWindow];
-	[[twc frontTerminalView] runProgram: filename
-		withArguments: nil
+	[[twc frontTerminalView] runProgram: @"/bin/sh"
+		withArguments: [NSArray arrayWithObjects: @"-c",filename,nil]
 		initialInput: nil];
 
 	return YES;
@@ -574,6 +590,8 @@
 
 	CREATE_AUTORELEASE_POOL(arp);
 
+	setlocale(LC_CTYPE, "");
+
 /*	[NSObject enableDoubleReleaseCheck: YES];*/
 
 	[TerminalApplication sharedApplication];
