Fix FTBFS with GCC 10: declare TerminalWindowNoMoreActiveWindowsNotification
as extern instead of a tentative definition.
Taken from the Debian terminal.app 0.9.9-5 source package.
Upstream: https://savannah.nongnu.org/bugs/?58583

--- TerminalWindow.h.orig
+++ TerminalWindow.h
@@ -17,7 +17,7 @@
 #import <AppKit/NSWindowController.h>
 #import <AppKit/NSTabView.h>
 
-NSString *TerminalWindowNoMoreActiveWindowsNotification;
+extern NSString *TerminalWindowNoMoreActiveWindowsNotification;
 
 @interface TerminalWindowController : NSWindowController
 {
