# $NetBSD: Makefile,v 1.5 2012/09/24 16:56:29 asau Exp $

DISTNAME=	terminal.app_0.9.9.orig
PKGNAME=	Terminal-0.9.9
CATEGORIES=	x11 gnustep
MASTER_SITES=	http://deb.debian.org/debian/pool/main/t/terminal.app/
DIST_SUBDIR=	terminal.app
WRKSRC=		${WRKDIR}/Terminal-0.9.9

MAINTAINER=	metaridley@mchsi.com
HOMEPAGE=	https://www.nongnu.org/backbone/apps.html
COMMENT=	GNUstep terminal emulator
LICENSE=	gnu-gpl-v2

USE_LANGUAGES=	objc
USE_TOOLS+=	gmake
MAKE_FILE=	GNUmakefile
NO_CONFIGURE=	yes

# Work around a crash in the pkgsrc LLVM libunwind's _Unwind_Backtrace on
# NetBSD (segfault in unw_getcontext during DWARF CFI parsing).  Link the
# base system's libgcc_s _Unwind_Backtrace before libunwind so the working
# implementation is used.
MAKE_FLAGS+=	ADDITIONAL_LDFLAGS=-lgcc_s


.include "../../devel/gnustep-base/buildlink3.mk"
.include "../../x11/gnustep-gui/buildlink3.mk"
.include "../../x11/gnustep-back/buildlink3.mk"
.include "../../mk/bsd.pkg.mk"
