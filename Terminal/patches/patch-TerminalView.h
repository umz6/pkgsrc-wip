Add alternate screen buffer ivars to TerminalView.

--- TerminalView.h.orig
+++ TerminalView.h
@@ -61,6 +61,9 @@
 	int sx,sy;
 	screen_char_t *screen;
 
+	screen_char_t *alt_screen;
+	int in_alt_screen, saved_sb_length;
+
 	int cursor_x,cursor_y;
 	int current_x,current_y;
 
