Add use_alt_screen flag to TerminalParser_Linux for DEC alternate
screen buffer support, and a decckm flag to track DEC private mode 1
(application cursor keys) so arrow keys are sent correctly.

Widen the foreground/background macros from 4-bit nibbles to 8-bit
bytes so the parser can store xterm 256-color indices (SGR 38;5;N /
48;5;N) in the 16-bit screen_char_t.color field.

--- TerminalParser_Linux.h.orig	2016-05-25 10:42:17.000000000 +0300
+++ TerminalParser_Linux.h	2026-08-14 15:37:44.080975853 +0300
@@ -45,14 +45,16 @@
 	unsigned char decscnm,decom,decawm,deccm,decim;
 	unsigned char ques;
 	unsigned char charset,utf,disp_ctrl,toggle_meta;
+	BOOL use_alt_screen;
+	BOOL decckm;
 	int G0_charset,G1_charset;
 
 	const unichar *translate;
 
 	unsigned int intensity,underline,reverse,blink;
 	unsigned int color,def_color;
-#define foreground (color & 0x0f)
-#define background (color & 0xf0)
+#define foreground (color & 0xff)
+#define background (color & 0xff00)
 
 	screen_char_t video_erase_char;
 
