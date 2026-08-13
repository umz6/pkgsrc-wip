Add ts_setAlternateScreen: to the TerminalScreen protocol so that the
parser can tell the view to switch between the primary and alternate
screen buffers.

Extend screen_char_t.color from unsigned char to unsigned short so the
low byte holds the 8-bit foreground color and the high byte the 8-bit
background color, enabling the xterm 256-color palette (SGR 38;5;N /
48;5;N).  Indices 0-15 are the standard VGA colors, 16-255 the xterm
256-color palette.

--- Terminal.h.orig	2016-01-17 01:45:00.000000000 +0300
+++ Terminal.h	2026-08-14 15:37:38.964033256 +0300
@@ -14,10 +14,13 @@
 typedef struct
 {
 	unichar ch;
-	unsigned char color;
+	unsigned short color;
 	unsigned char attr;
 /*
-bits
+color: low byte = foreground (0-255), high byte = background (0-255).
+0-15 are the standard VGA colors, 16-255 are the xterm 256-color palette.
+
+attr bits
 0,1   intensity, 0-2
 2     underline
 3     reverse
@@ -52,6 +55,8 @@
 
 -(void) ts_setTitle: (NSString *)new_title  type: (int)title_type;
 
+-(void) ts_setAlternateScreen: (BOOL)on;
+
 
 -(BOOL) useMultiCellGlyphs;
 -(int) relativeWidthOfCharacter: (unichar)ch;
