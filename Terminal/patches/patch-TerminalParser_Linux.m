Use ucs-4be (big-endian, no BOM) for iconv instead of ucs-4, which
emits a BOM and is little-endian on NetBSD, breaking the parser.

Wrap PUTCH macro body in "if (char_width>0)" so zero-width characters
are silently dropped instead of occupying a cell and rendering as an
empty rectangle.

Handle DEC private modes 47/1047/1049 (alternate screen buffer) in
_set_mode: so TUI applications can switch to the alternate screen.
Mode 1049 saves/restores the cursor position.

Track DEC private mode 1 (application cursor keys, DECCKM) in a real
decckm flag and send \eOA/\eOB/\eOC/\eOD for the arrow keys while it
is set.  Without this, TUI applications (mc, vim, etc.) that enable
application cursor mode via smkx do not recognize the arrow keys.

Send the standard xterm F1-F5 sequences (\eOP-\eOS, \e[15~) instead of
the Linux console sequences (\e[[A-\e[[E) so function keys work in
TUI applications (mc, etc.) under TERM=xterm.

Send the terminfo xterm-256color Home/End sequences (\eOH, \eOF)
instead of the Linux console sequences (\e[1~, \e[4~).  The khome/kend
capabilities of xterm-256color are \eOH/\eOF; shells that bind keys
from terminfo (NetBSD /bin/ksh, pdksh) only recognize those.  bash's
readline additionally hardcodes \e[H/\e[F, which is why \e[H/\e[F
worked in bash but left Home/End dead in ksh.

Implement CSI S / CSI T (SU/SD: scroll text up/down within the scroll
region, honoring DECSTBM) which modern TUI renderers (qwen-code, etc.)
use to scroll their viewport.  Previously these sequences were silently
ignored, leaving the display desynchronized from the application.

Remove debug NSLog() calls left over from alternate-screen development
that spammed the console log on every set_mode() call and screen switch.

Add full SGR (Select Graphic Rendition) support to _csi_m so that
diff --color and other colorizing tools render correctly.  Handle the
extended color sequences 38;5;N / 48;5;N (xterm 256-color palette),
the bright colors 90-97 / 100-107, and the missing attribute codes
(3/6/8/9 and their off codes 23/26/28/29).  The previous 38/39/49
cases used the SCO interpretation (forcing underline/white); replace
them with the standard xterm semantics.  Truecolor (38;2;r;g;b) is
intentionally not supported and is skipped.

--- TerminalParser_Linux.m.orig	2016-05-20 00:53:59.000000000 +0300
+++ TerminalParser_Linux.m	2026-08-14 20:01:30.270997311 +0300
@@ -156,6 +156,7 @@
 	decawm		= 1;
 	deccm		= 1;
 	decim		= 0;
+	decckm		= 0;
 
 #if 0
 	set_kbd(decarm);
@@ -280,15 +281,22 @@
 			case 2:
 				intensity = 0;
 				break;
+			case 3:	/* italic: not supported, ignore */
+				break;
 			case 4:
 				underline = 1;
 				break;
 			case 5:
+			case 6:	/* rapid blink: same as blink */
 				blink = 1;
 				break;
 			case 7:
 				reverse = 1;
 				break;
+			case 8:	/* conceal: not supported, ignore */
+				break;
+			case 9:	/* strikethrough: not supported, ignore */
+				break;
 			case 10: /* ANSI X3.64-1979 (SCO-ish?)
 				  * Select primary font, don't display
 				  * control chars if defined, don't set
@@ -320,41 +328,81 @@
 			case 22:
 				intensity = 1;
 				break;
+			case 23: /* italic off */
+				break;
 			case 24:
 				underline = 0;
 				break;
 			case 25:
+			case 26:
 				blink = 0;
 				break;
 			case 27:
 				reverse = 0;
 				break;
-			case 38: /* ANSI X3.64-1979 (SCO-ish?)
-				  * Enables underscore, white foreground
-				  * with white underscore (Linux - use
-				  * default foreground).
-				  */
-				color = (def_color & 0x0f) | background;
-				underline = 1;
+			case 28: /* conceal off */
 				break;
-			case 39: /* ANSI X3.64-1979 (SCO-ish?)
-				  * Disable underline option.
-				  * Reset colour to default? It did this
-				  * before...
-				  */
-				color = (def_color & 0x0f) | background;
-				underline = 0;
+			case 29: /* strikethrough off */
 				break;
-			case 49:
-				color = (def_color & 0xf0) | foreground;
+			case 38: /* extended foreground color */
+				if (i+1 <= npar && par[i+1] == 5 && i+2 <= npar)
+				{
+					/* 256-color: 38;5;N */
+					int idx = par[i+2];
+					if (idx < 16)
+						color = (color & 0xff00) | color_table[idx];
+					else
+						color = (color & 0xff00) | idx;
+					i += 2;
+				}
+				else if (i+1 <= npar && par[i+1] == 2)
+				{
+					/* truecolor: 38;2;r;g;b -- not supported, skip */
+					i += 4;
+				}
+				else
+				{
+					/* plain 38: default foreground */
+					color = (color & 0xff00) | (def_color & 0xff);
+				}
+				break;
+			case 39: /* default foreground */
+				color = (color & 0xff00) | (def_color & 0xff);
+				break;
+			case 48: /* extended background color */
+				if (i+1 <= npar && par[i+1] == 5 && i+2 <= npar)
+				{
+					/* 256-color: 48;5;N */
+					int idx = par[i+2];
+					if (idx < 16)
+						color = (color & 0x00ff) | (color_table[idx] << 8);
+					else
+						color = (color & 0x00ff) | (idx << 8);
+					i += 2;
+				}
+				else if (i+1 <= npar && par[i+1] == 2)
+				{
+					/* truecolor: 48;2;r;g;b -- not supported, skip */
+					i += 4;
+				}
+				else
+				{
+					/* plain 48: default background */
+					color = (color & 0x00ff) | (def_color & 0xff00);
+				}
+				break;
+			case 49: /* default background */
+				color = (color & 0x00ff) | (def_color & 0xff00);
 				break;
 			default:
 				if (par[i] >= 30 && par[i] <= 37)
-					color = color_table[par[i]-30]
-						| background;
+					color = (color & 0xff00) | color_table[par[i]-30];
 				else if (par[i] >= 40 && par[i] <= 47)
-					color = (color_table[par[i]-40]<<4)
-						| foreground;
+					color = (color & 0x00ff) | (color_table[par[i]-40]<<8);
+				else if (par[i] >= 90 && par[i] <= 97)
+					color = (color & 0xff00) | color_table[par[i]-90+8];
+				else if (par[i] >= 100 && par[i] <= 107)
+					color = (color & 0x00ff) | (color_table[par[i]-100+8]<<8);
 				break;
 		}
 
@@ -447,14 +495,7 @@
 	for (i=0; i<=npar; i++)
 		if (ques) switch(par[i]) {	/* DEC private modes set/reset */
 			case 1:			/* Cursor keys send ^[Ox/^[[x */
-				if (on_off)
-				{
-					set_kbd(decckm);
-				}
-				else
-				{
-					clr_kbd(decckm);
-				}
+				decckm = on_off;
 				break;
 			case 3:	/* 80/132 mode switch unimplemented */
 				NSDebugLLog(@"term",@"ignore _set_mode 3");
@@ -496,6 +537,24 @@
 			case 25:		/* Cursor on/off */
 				deccm = on_off;
 				break;
+			case 47:		/* Alternate screen (no clear) */
+			case 1047:		/* Alternate screen, clear on exit */
+			case 1049:		/* Alternate screen, save/restore cursor */
+				if (on_off && !use_alt_screen)
+				{
+					use_alt_screen = YES;
+					if (par[i] == 1049)
+						save_cur(currcons);
+					[ts ts_setAlternateScreen: YES];
+				}
+				else if (!on_off && use_alt_screen)
+				{
+					use_alt_screen = NO;
+					[ts ts_setAlternateScreen: NO];
+					if (par[i] == 1049)
+						restore_cur(currcons);
+				}
+				break;
 			case 1000:
 				NSDebugLLog(@"term",@"ignore _set_mode 1000");
 #if 0
@@ -920,6 +979,14 @@
 		case 'K':
 			csi_K(currcons,par[0]);
 			return;
+		case 'S':
+			if (!par[0]) par[0]++;
+			scrup(currcons,top,bottom,par[0],(top==0 && bottom==height)?YES:NO);
+			return;
+		case 'T':
+			if (!par[0]) par[0]++;
+			scrdown(currcons,top,bottom,par[0]);
+			return;
 		case 'L':
 			csi_L(currcons,par[0]);
 			return;
@@ -1101,22 +1168,25 @@
 		lf(); \
 	} \
 	char_width=[ts relativeWidthOfCharacter: ch.ch]; \
-	if (decim) \
-		[ts ts_shiftRow: y  at: x  delta: char_width]; \
-	[ts ts_putChar: ch  count: 1  at: x:y]; \
-	if (x<width) \
+	if (char_width>0) \
 	{ \
-		x++; \
-		char_width--; \
-		if (char_width+x>width) \
-			char_width=width-x; \
-		if (char_width>0) \
+		if (decim) \
+			[ts ts_shiftRow: y  at: x  delta: char_width]; \
+		[ts ts_putChar: ch  count: 1  at: x:y]; \
+		if (x<width) \
 		{ \
-			ch.ch=MULTI_CELL_GLYPH; \
-			[ts ts_putChar: ch  count: char_width  at: x:y]; \
-			x+=char_width; \
+			x++; \
+			char_width--; \
+			if (char_width+x>width) \
+				char_width=width-x; \
+			if (char_width>0) \
+			{ \
+				ch.ch=MULTI_CELL_GLYPH; \
+				[ts ts_putChar: ch  count: char_width  at: x:y]; \
+				x+=char_width; \
+			} \
+			[ts ts_goto: x:y]; \
 		} \
-		[ts ts_goto: x:y]; \
 	}
 
 		{
@@ -1291,16 +1361,16 @@
 			str="\e";
 		break;
 
-	case NSUpArrowFunctionKey   : str="\e[A"; break;
-	case NSDownArrowFunctionKey : str="\e[B"; break;
-	case NSLeftArrowFunctionKey : str="\e[D"; break;
-	case NSRightArrowFunctionKey: str="\e[C"; break;
-
-	case NSF1FunctionKey : str="\e[[A"; break;
-	case NSF2FunctionKey : str="\e[[B"; break;
-	case NSF3FunctionKey : str="\e[[C"; break;
-	case NSF4FunctionKey : str="\e[[D"; break;
-	case NSF5FunctionKey : str="\e[[E"; break;
+	case NSUpArrowFunctionKey   : str=decckm?"\eOA":"\e[A"; break;
+	case NSDownArrowFunctionKey : str=decckm?"\eOB":"\e[B"; break;
+	case NSLeftArrowFunctionKey : str=decckm?"\eOD":"\e[D"; break;
+	case NSRightArrowFunctionKey: str=decckm?"\eOC":"\e[C"; break;
+
+	case NSF1FunctionKey : str="\eOP"; break;
+	case NSF2FunctionKey : str="\eOQ"; break;
+	case NSF3FunctionKey : str="\eOR"; break;
+	case NSF4FunctionKey : str="\eOS"; break;
+	case NSF5FunctionKey : str="\e[15~"; break;
 
 	case NSF6FunctionKey : str="\e[17~"; break;
 	case NSF7FunctionKey : str="\e[18~"; break;
@@ -1319,10 +1389,10 @@
 	case NSF19FunctionKey: str="\e[33~"; break;
 	case NSF20FunctionKey: str="\e[34~"; break;
 
-	case NSHomeFunctionKey    : str="\e[1~"; break;
+	case NSHomeFunctionKey    : str="\eOH"; break;
 	case NSInsertFunctionKey  : str="\e[2~"; break;
 	case NSDeleteFunctionKey  : str="\e[3~"; break;
-	case NSEndFunctionKey     : str="\e[4~"; break;
+	case NSEndFunctionKey     : str="\eOF"; break;
 	case NSPageUpFunctionKey  : str="\e[5~"; break;
 	case NSPageDownFunctionKey: str="\e[6~"; break;
 
@@ -1413,7 +1483,7 @@
 
 	if (strcmp(iconv_charset,"iso-8859-1"))
 	{
-		iconv_state=iconv_open("ucs-4",iconv_charset);
+		iconv_state=iconv_open("ucs-4be",iconv_charset);
 		if (iconv_state==(iconv_t)-1)
 		{
 			iconv_state=NULL;
@@ -1422,7 +1492,7 @@
 			NSLog(@"Falling back to iso-8859-1 (latin1).");
 		}
 
-		iconv_input_state=iconv_open(iconv_charset,"ucs-4");
+		iconv_input_state=iconv_open(iconv_charset,"ucs-4be");
 		if (iconv_input_state==(iconv_t)-1)
 		{
 			iconv_input_state=NULL;
