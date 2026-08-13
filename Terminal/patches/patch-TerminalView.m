Fix FTBFS on GNU/kFreeBSD: include termio.h for glibc.
Fix int-to-pointer-cast GCC warning. Check write() return value.
Default the character set to UTF-8 instead of iso-8859-1.
Taken from the Debian terminal.app 0.9.9-5 source package.

Use wcwidth(3) for character widths so zero-width characters (variation
selectors U+FE0E/U+FE0F) are width 0, not empty rectangles.  Requires
setlocale(LC_CTYPE, "") in main.m.

A character with wcwidth()==1 must always occupy exactly one cell:
measuring glyph ink (boundingRectForGlyph) is only used to widen
characters that wcwidth() itself reports as double-width (w >= 2).
Ink measurement made characters whose glyph ink slightly exceeds the
cell width (braille spinner characters U+2800..U+28FF rendered from a
fallback font, arrows, check marks, etc.) occupy two cells, shifting
the rest of the line and producing artifacts when TUI applications
(qwen-code) scroll or redraw lines.

Implement DEC alternate screen buffer (modes 47/1047/1049) so TUI apps
like qwen-code can disable the scrollbar.  Saves/restores the primary
screen and scrollback, skips scrollback saving while in alt screen.

Make _scrollTo: a no-op while in the alternate screen so that scroll
commands (Shift+PgUp/PgDn, scroll wheel) cannot corrupt the scroll state
of a TUI application running in the alternate screen.

Remove a debug NSLog() left over from alternate-screen development that
spammed the console log on every screen switch.

Set TERM=xterm-256color instead of TERM=linux so that TUI applications
(less, qwen-code, etc.) send the DEC alternate screen escape sequence
(\e[?1049h) and can disable the scrollbar, and so that 256-color SGR
sequences are advertised.  The linux terminfo entry has no smcup/rmcup
(alternate screen) capability.

Add SGR (Select Graphic Rendition) support so that diff --color and
other colorizing tools render correctly.  Extend the per-cell color
field to 16 bits (8-bit foreground + 8-bit background) to hold the
xterm 256-color palette, add a set_xterm_color() helper that converts
a 256-color index to HSB, and teach set_foreground()/set_background()
to use it for indices 16-255.  Truecolor (24-bit) is intentionally not
supported.

--- TerminalView.m.orig	2017-08-02 20:17:43.000000000 +0300
+++ TerminalView.m	2026-08-14 19:14:34.866876313 +0300
@@ -26,6 +26,7 @@
 
 #include <math.h>
 #include <unistd.h>
+#include <wchar.h>
 
 #ifdef __NetBSD__
 #  include <sys/types.h>
@@ -44,7 +45,7 @@
 #  include <termios.h>
 #  include <util.h>
 #  include <sys/ioctl.h>
-#elif defined (__GNU__)
+#elif defined (__GNU__) || defined (__GLIBC__)
 #else
 #  include <termio.h>
 #endif
@@ -395,11 +396,62 @@
 static const float col_h[8]={  0,240,120,180,  0,300, 60,  0};
 static const float col_s[8]={0.0,1.0,1.0,1.0,1.0,1.0,1.0,0.0};
 
+/* Convert an xterm 256-color palette index (16-255) to an HSB color.
+ * 16-231: 6x6x6 color cube, 232-255: grayscale ramp. */
+static void set_xterm_color(NSGraphicsContext *gc,int idx)
+{
+	int r,g,b;
+	float h,s,v,max,min,delta;
+
+	if (idx<232)
+	{
+		idx-=16;
+		r=(idx/36)%6;
+		g=(idx/6)%6;
+		b=idx%6;
+		r=(r==0)?0:55+r*40;
+		g=(g==0)?0:55+g*40;
+		b=(b==0)?0:55+b*40;
+	}
+	else
+	{
+		v=8+(idx-232)*10;
+		r=g=b=(int)v;
+	}
+
+	max=(r>g)?((r>b)?r:b):((g>b)?g:b);
+	min=(r<g)?((r<b)?r:b):((g<b)?g:b);
+	v=max/255.0;
+	delta=max-min;
+	if (max==0)
+		s=0;
+	else
+		s=delta/max;
+	if (delta==0)
+		h=0;
+	else if (max==r)
+		h=60.0*fmod(((g-b)/delta),6.0);
+	else if (max==g)
+		h=60.0*(((b-r)/delta)+2.0);
+	else
+		h=60.0*(((r-g)/delta)+4.0);
+	if (h<0)
+		h+=360.0;
+
+	DPSsethsbcolor(gc,h/360.0,s,v);
+}
+
 static void set_background(NSGraphicsContext *gc,
-	unsigned char color,unsigned char in)
+	unsigned short color,unsigned char in)
 {
 	float bh,bs,bb;
-	int bg=color>>4;
+	int bg=color>>8;
+
+	if (bg>=16)
+	{
+		set_xterm_color(gc,bg);
+		return;
+	}
 
 	if (bg==0)
 		bb=0.0;
@@ -414,11 +466,17 @@
 }
 
 static void set_foreground(NSGraphicsContext *gc,
-	unsigned char color,unsigned char in, BOOL blackOnWhite)
+	unsigned short color,unsigned char in, BOOL blackOnWhite)
 {
 	int fg=color;
 	float h,s,b;
 
+	if (fg>=16)
+	{
+		set_xterm_color(gc,fg);
+		return;
+	}
+
 if (blackOnWhite)
   {
     if (color == 0) { fg = 7; in = 2; }		// Black becomes white
@@ -522,7 +580,8 @@
 		float scr_y,scr_x,start_x;
 
 		/* setting the color is slow, so we try to avoid it */
-		unsigned char l_color,l_attr,color;
+		unsigned short l_color,color;
+		unsigned char l_attr;
 
 		/* Fill the background of dirty cells. Since the background doesn't
 		change that often, runs of dirty cells with the same background color
@@ -568,8 +627,8 @@
 
 				if (ch->attr&0x8)
 				{
-					color=ch->color&0xf;
-					if (ch->attr&0x40) color^=0xf;
+					color=ch->color&0xff;
+					if (ch->attr&0x40) color^=0xff;
 					if (color!=l_color || (ch->attr&0x03)!=l_attr)
 					{
 						if (start_x!=-1)
@@ -585,8 +644,8 @@
 				}
 				else
 				{
-					color=ch->color&0xf0;
-					if (ch->attr&0x40) color^=0xf0;
+					color=ch->color&0xff00;
+					if (ch->attr&0x40) color^=0xff00;
 					if (color!=l_color)
 					{
 						if (start_x!=-1)
@@ -637,8 +696,8 @@
 				{
 					if (!(ch->attr&0x8))
 					{
-						color=ch->color&0xf;
-						if (ch->attr&0x40) color^=0xf;
+						color=ch->color&0xff;
+						if (ch->attr&0x40) color^=0xff;
 						if (color!=l_color || (ch->attr&0x03)!=l_attr)
 						{
 							l_color=color;
@@ -648,8 +707,8 @@
 					}
 					else
 					{
-						color=ch->color&0xf0;
-						if (ch->attr&0x40) color^=0xf0;
+						color=ch->color&0xff00;
+						if (ch->attr&0x40) color^=0xff00;
 						if (color!=l_color)
 						{
 							l_color=color;
@@ -834,6 +893,32 @@
 		object: self];
 }
 
+-(void) ts_setAlternateScreen: (BOOL)on
+{
+	if (on && !in_alt_screen)
+	{
+		memcpy(alt_screen, screen, sizeof(screen_char_t)*sx*sy);
+		memset(screen, 0, sizeof(screen_char_t)*sx*sy);
+		saved_sb_length = sb_length;
+		sb_length = 0;
+		in_alt_screen = YES;
+		current_scroll = 0;
+		draw_all = 2;
+		[self _updateScroller];
+		[self setNeedsDisplay: YES];
+	}
+	else if (!on && in_alt_screen)
+	{
+		memcpy(screen, alt_screen, sizeof(screen_char_t)*sx*sy);
+		sb_length = saved_sb_length;
+		in_alt_screen = NO;
+		current_scroll = 0;
+		draw_all = 2;
+		[self _updateScroller];
+		[self setNeedsDisplay: YES];
+	}
+}
+
 
 -(void) ts_goto: (int)x :(int)y
 {
@@ -901,6 +986,8 @@
 	if (save && t==0 && b==sy) /* TODO? */
 	{
 		int num;
+		if (in_alt_screen)
+			goto skip_saveback;
 		if (nr<max_scrollback)
 		{
 			memmove(sbuf,&sbuf[sx*nr],sizeof(screen_char_t)*sx*(max_scrollback-nr));
@@ -924,6 +1011,7 @@
 		if (sb_length>max_scrollback)
 			sb_length=max_scrollback;
 	}
+skip_saveback:
 
 	if (t+nr >= b)
 		nr = b - t - 1;
@@ -1150,8 +1238,15 @@
 
 -(int) relativeWidthOfCharacter: (unichar)ch
 {
+	int w;
 	int s;
-	if (!use_multi_cell_glyphs)
+
+	w = wcwidth(ch);
+	if (w == 0)
+		return 0;
+	if (w == 1)
+		return 1;
+	if (!use_multi_cell_glyphs || w < 0)
 		return 1;
 	s=ceil([font boundingRectForGlyph: ch].size.width/fx);
 	if (s<1)
@@ -1191,6 +1286,8 @@
 
 -(void) _scrollTo: (int)new_scroll  update: (BOOL)update
 {
+	if (in_alt_screen)
+		return;
 	if (new_scroll>0)
 		new_scroll=0;
 	if (new_scroll<-sb_length)
@@ -1987,7 +2084,7 @@
 		if (cdirectory)
 			if (chdir(cdirectory) < 0)
 				fprintf(stderr, "Unable do set directory: %s\n", cdirectory);
-		putenv("TERM=linux");
+		putenv("TERM=xterm-256color");
 		putenv("TERM_PROGRAM=GNUstep_Terminal");
 		execv(cpath,(char *const*)cargs);
 		fprintf(stderr,"Unable to spawn process '%s': %m!",cpath);
@@ -2009,7 +2106,7 @@
 	}
 
 	rl=[NSRunLoop currentRunLoop];
-	[rl addEvent: (void *)master_fd
+	[rl addEvent: (void *)(intptr_t)master_fd
 		type: ET_RDESC
 		watcher: self
 		forMode: NSDefaultRunLoopMode];
@@ -2022,7 +2119,12 @@
 	{
 		const char *s=[d UTF8String];
 		close(pipefd[0]);
-		write(pipefd[1],s,strlen(s));
+		if (write(pipefd[1],s,strlen(s)) < 0)
+		{
+			NSLog(_(@"Unexpected error while writing."));
+			close(pipefd[1]);
+			return;
+		}
 		close(pipefd[1]);
 	}
 
@@ -2198,6 +2300,20 @@
 	}
 	memset(nscreen,0,sizeof(screen_char_t)*nsx*nsy);
 	memset(nsbuf,0,sizeof(screen_char_t)*nsx*max_scrollback);
+	{
+		screen_char_t *nalt;
+		nalt=malloc(nsx*nsy*sizeof(screen_char_t));
+		if (!nalt)
+		{
+			NSLog(@"Failed to allocate alt screen buffer!");
+			free(nscreen);
+			free(nsbuf);
+			return;
+		}
+		memset(nalt,0,sizeof(screen_char_t)*nsx*nsy);
+		free(alt_screen);
+		alt_screen=nalt;
+	}
 
 	copy_sx=sx;
 	if (copy_sx>nsx)
@@ -2311,6 +2427,11 @@
 	memset(screen,0,sizeof(screen_char_t)*sx*sy);
 	draw_all=2;
 
+	alt_screen=malloc(sizeof(screen_char_t)*sx*sy);
+	memset(alt_screen,0,sizeof(screen_char_t)*sx*sy);
+	in_alt_screen=NO;
+	saved_sb_length=0;
+
 	max_scrollback=[TerminalViewDisplayPrefs scrollBackLines];
 	sbuf=malloc(sizeof(screen_char_t)*sx*max_scrollback);
 	memset(sbuf,0,sizeof(screen_char_t)*sx*max_scrollback);
@@ -2346,8 +2467,10 @@
 
 	free(screen);
 	free(sbuf);
+	free(alt_screen);
 	screen=NULL;
 	sbuf=NULL;
+	alt_screen=NULL;
 
 	DESTROY(font);
 	DESTROY(boldFont);
