$NetBSD$

On X11, Qt6 synthesizes pixelDelta from angleDelta with unreliable
scaling, causing one mouse wheel notch to scroll multiple screens.
Only use pixelDelta on Wayland or touchpad input; fall through to
angleDelta for mouse wheel events on X11, which normalizes to 120
per notch.

--- Telegram/lib_ui/ui/ui_utility.cpp.orig	2026-08-03 12:00:00.000000000 +0300
+++ Telegram/lib_ui/ui/ui_utility.cpp
@@ -274,7 +274,7 @@
 			style::ConvertScaleExact(point.x()),
 			style::ConvertScaleExact(point.y()));
 	};
-	if (!e->pixelDelta().isNull()) {
+	if (!e->pixelDelta().isNull() && (::Platform::IsWayland() || touch)) {
 		return convert(e->pixelDelta())
 			* ((::Platform::IsWayland() && !touch)
 				? kMagicScrollMultiplier
