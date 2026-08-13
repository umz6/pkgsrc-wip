Default the character set to UTF-8 instead of iso-8859-1.
Taken from the Debian terminal.app 0.9.9-5 source package.

--- TerminalParser_LinuxPrefs.m.orig
+++ TerminalParser_LinuxPrefs.m
@@ -59,7 +59,7 @@
 
 		characterSet=[[ud stringForKey: CharacterSetKey] retain];
 		if (!characterSet)
-			characterSet=@"iso-8859-1";
+			characterSet=@"utf-8";
 	}
 }
 
