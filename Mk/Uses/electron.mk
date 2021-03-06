# $FreeBSD$
#
# Provides support for Electron-based ports
#
# Feature:	electron
# Usage:	USES=electron[:ARGS]
# Valid ARGS:	<version>, build, run, test
#
# <version>:	Indicates a specific major version of Electron the port uses.
#
# build:	Indicates Electron is needed at build time and adds it to
#		BUILD_DEPENDS.
# run:		Indicates Electron is needed at run time and adds it to
#		RUN_DEPENDS.
# test:		Indicates Electron is needed at test time and adds it to
#		TEST_DEPENDS.
#
# NOTE: If the port specifies none of build, run or test, we assume the port
# requires all those dependencies.
#
# Variables, which can be set by the port:
#
# USE_ELECTRON:		A list of additional features and functionalities to
#			enable. Supported features are:
#
# NOTE: Roughly speaking, these features are for doing "npm install" or "yarn
# install" divided into multiple phases.
#
#	prefetch:	Downloads node modules the port uses according to the
#			pre-stored package.json (and package-lock.json or
#			yarn.lock depending on node package manager used) in
#			PKGJSONSDIR. Downloaded modules are archived into a
#			single tar file as one of the DISTFILES.
#
#			If the port uses this feature, the following variable
#			must be specified.
#
#		PREFETCH_TIMESTAMP:
#			A timestamp given to every directory or file in the tar
#			archive. This is necessary for reproducibility of the
#			archive.
#
#	extract:	Installs the pre-fetched node modules into the port's
#			working source directory.
#
#	prebuild:	Rebuilds native node modules against the installed Node
#			so that the Node can execute the native modules.
#
#			If the port uses this feature and the electron major
#			version is less than 6, the following variable must be
#			specified.
#
#		UPSTREAM_ELECTRON_VER:
#			An electron version which is specified in
#			package-lock.json or yarn.lock in the source archive.
#			The build process will generate a zip file and a
#			checksum file from locally installed electron to prevent
#			@electron/get tries to download electron's binary
#			distribution during build phase.
#
#			If the port uses this feature and the port depends on
#			chromedriver distribution, the following variable must
#			be specified.
#
#		UPSTREAM_CHROMEDRIVER_VER:
#			A chromedriver version which is specified in
#			package-lock.json or yarn.lock in the source archive.
#			The build process will generate a zip file and a
#			checksum file from locally installed electron to prevent
#			@electron/get tries to download chromedriver's binary
#			distribution during build phase.
#
#		NOTE: The generated files are just used to prevent download and
#		will not be used for other purposes. This is ugly but necessary.
#
# MAINTAINER:	tagattie@yandex.com

.if !defined(_INCLUDE_USES_ELECTRON_MK)
_INCLUDE_USES_ELECTRON_MK=	yes

# Electron uses Node (actually a package manager) for build
.include "${USESDIR}/node.mk"

_VALID_ELECTRON_VERSIONS=	4 5 6 7
_VALID_ELECTRON_FEATURES=	prefetch extract prebuild

_ELECTRON_BASE_CMD=	electron

_ELECTRON_RELPORTDIR=	devel/electron

# Detect a build, run or test time dependencies on Electron
_ELECTRON_ARGS=		${electron_ARGS:S/,/ /g}
.if ${_ELECTRON_ARGS:Mbuild}
_ELECTRON_BUILD_DEP=	yes
_ELECTRON_ARGS:=	${_ELECTRON_ARGS:Nbuild}
.endif
.if ${_ELECTRON_ARGS:Mrun}
_ELECTRON_RUN_DEP=	yes
_ELECTRON_ARGS:=	${_ELECTRON_ARGS:Nrun}
.endif
.if ${_ELECTRON_ARGS:Mtest}
_ELECTRON_TEST_DEP=	yes
_ELECTRON_ARGS:=	${_ELECTRON_ARGS:Ntest}
.endif

# If the port does not specify any dependency, assume all are required
.if !defined(_ELECTRON_BUILD_DEP) && !defined(_ELECTRON_RUN_DEP) && \
    !defined(_ELECTRON_TEST_DEP)
_ELECTRON_BUILD_DEP=	yes
_ELECTRON_RUN_DEP=	yes
_ELECTRON_TEST_DEP=	yes
.endif

# Now _ELECTRON_ARGS should contain a single major version
.if ${_VALID_ELECTRON_VERSIONS:M${_ELECTRON_ARGS}}
_ELECTRON_VERSION=	${_ELECTRON_ARGS}
_ELECTRON_PORTDIR=	${_ELECTRON_RELPORTDIR}${_ELECTRON_VERSION}
.include "${PORTSDIR}/devel/electron${_ELECTRON_VERSION}/Makefile.version"
.else
IGNORE= uses unknown USES=electron arguments: ${_ELECTRON_ARGS}
.endif

# Detect features used with USE_ELECTRON
.for var in ${USE_ELECTRON}
.   if empty(_VALID_ELECTRON_FEATURES:M${var})
_INVALID_ELECTRON_FEATURES+=	${var}
.   endif
.endfor
.if !empty(_INVALID_ELECTRON_FEATURES)
IGNORE=	uses unknown USE_ELECTRON features: ${_INVALID_ELECTRON_FEATURES}
.endif

# Make each individual feature available as _ELECTRON_FEATURE_<FEATURENAME>
.for var in ${USE_ELECTRON}
_ELECTRON_FEATURE_${var:tu}=	${var}
.endfor

# Setup dependencies
.for stage in BUILD RUN TEST
.   if defined(_ELECTRON_${stage}_DEP)
${stage}_DEPENDS+=	${_ELECTRON_BASE_CMD}${_ELECTRON_VERSION}:${_ELECTRON_PORTDIR}
.   endif
.endfor

ELECTRON_VERSION=	${_ELECTRON_VERSION}
ELECTRON_PORTDIR=	${_ELECTRON_PORTDIR}

PKGJSONSDIR?=		${FILESDIR}/packagejsons
PREFETCH_TIMESTAMP?=	0

.if defined(_ELECTRON_FEATURE_PREFETCH)
_DISTFILE_prefetch=	${PORTNAME}-node-modules-${DISTVERSION}${EXTRACT_SUFX}
DISTFILES+=		${_DISTFILE_prefetch}:prefetch

.   if ${PREFETCH_TIMESTAMP} == 0
IGNORE= does not specify timestamp for pre-fetched modules
.   endif

FETCH_DEPENDS+= ${NODE_PKG_MANAGER}:${${NODE_PKG_MANAGER:tu}_PORTDIR}
_USES_fetch+=	490:electron-fetch-node-modules
.   if ${NODE_PKG_MANAGER} == npm
electron-fetch-node-modules:
	@${MKDIR} ${DISTDIR}/${DIST_SUBDIR}
	@if [ ! -f ${DISTDIR}/${DIST_SUBDIR}/${_DISTFILE_prefetch} ]; then \
		${ECHO_MSG} "===>  Pre-fetching and archiving node modules"; \
		${MKDIR} ${WRKDIR}/npm-cache; \
		${CP} -r ${PKGJSONSDIR}/* ${WRKDIR}/npm-cache; \
		cd ${PKGJSONSDIR} && \
		for dir in `${FIND} . -type f -name package.json -exec dirname {} ';'`; do \
			cd ${WRKDIR}/npm-cache/$${dir} && \
			${SETENV} HOME=${WRKDIR} ${NPM_CMD} ci --ignore-scripts --no-progress && \
			${RM} package.json package-lock.json; \
		done; \
		cd ${WRKDIR} && \
		${MTREE_CMD} -cbnSp npm-cache | ${MTREE_CMD} -C | ${SED} \
			-e 's:time=[0-9.]*:time=${PREFETCH_TIMESTAMP}.000000000:' \
			-e 's:\([gu]id\)=[0-9]*:\1=0:g' \
			-e 's:flags=.*:flags=none:' \
			-e 's:^\.:./npm-cache:' > npm-cache.mtree && \
		${TAR} -cz --options 'gzip:!timestamp' \
			-f ${DISTDIR}/${DIST_SUBDIR}/${_DISTFILE_prefetch} @npm-cache.mtree; \
		${RM} -r ${WRKDIR}; \
	fi
.   elif ${NODE_PKG_MANAGER} == yarn
electron-fetch-node-modules:
	@${MKDIR} ${DISTDIR}/${DIST_SUBDIR}
	@if [ ! -f ${DISTDIR}/${DIST_SUBDIR}/${_DISTFILE_prefetch} ]; then \
		${ECHO_MSG} "===>  Pre-fetching and archiving node modules"; \
		${MKDIR} ${WRKDIR}; \
		${ECHO_CMD} 'yarn-offline-mirror "./yarn-offline-cache"' >> \
			${WRKDIR}/.yarnrc; \
		${CP} -r ${PKGJSONSDIR}/* ${WRKDIR}; \
		cd ${PKGJSONSDIR} && \
		for dir in `${FIND} . -type f -name package.json -exec dirname {} ';'`; do \
			cd ${WRKDIR}/$${dir} && \
			${SETENV} HOME=${WRKDIR} XDG_CACHE_HOME=${WRKDIR}/.cache \
				${YARN_CMD} --frozen-lockfile --ignore-scripts && \
			${RM} package.json yarn.lock; \
		done; \
		cd ${WRKDIR}; \
		${MTREE_CMD} -cbnSp yarn-offline-cache | ${MTREE_CMD} -C | ${SED} \
			-e 's:time=[0-9.]*:time=${PREFETCH_TIMESTAMP}.000000000:' \
			-e 's:\([gu]id\)=[0-9]*:\1=0:g' \
			-e 's:flags=.*:flags=none:' \
			-e 's:^\.:./yarn-offline-cache:' > yarn-offline-cache.mtree; \
		${TAR} -cz --options 'gzip:!timestamp' \
			-f ${DISTDIR}/${DIST_SUBDIR}/${_DISTFILE_prefetch} @yarn-offline-cache.mtree; \
		${RM} -r ${WRKDIR}; \
	fi
.   endif
.endif # _FEATURE_ELECTRON_PREFETCH

.if defined(_ELECTRON_FEATURE_EXTRACT)
.   if ${NODE_PKG_MANAGER} == npm
_USES_extract+=	690:electron-install-node-modules
electron-install-node-modules:
	@${ECHO_MSG} "===>  Copying package.json and package-lock.json to WRKSRC"
	@cd ${PKGJSONSDIR} && \
	for dir in `${FIND} . -type f -name package.json -exec dirname {} ';'`; do \
		for f in package.json package-lock.json; do \
			if [ -f ${WRKSRC}/$${dir}/$${f} ]; then \
				${MV} -f ${WRKSRC}/$${dir}/$${f} ${WRKSRC}/$${dir}/$${f}.bak; \
			fi; \
			${CP} -f $${dir}/$${f} ${WRKSRC}/$${dir}; \
		done; \
	done
	@${ECHO_MSG} "===>  Moving pre-fetched node modules to WRKSRC"
	@cd ${PKGJSONSDIR} && \
	for dir in `${FIND} . -type f -name package.json -exec dirname {} ';'`; do \
		${MV} ${WRKDIR}/npm-cache/$${dir}/node_modules ${WRKSRC}/$${dir}; \
	done
.   elif ${NODE_PKG_MANAGER} == yarn
EXTRACT_DEPENDS+= ${NODE_PKG_MANAGER}:${${NODE_PKG_MANAGER:tu}_PORTDIR}
_USES_extract+=	690:electron-install-node-modules
electron-install-node-modules:
	@${ECHO_MSG} "===>  Copying package.json and yarn.lock to WRKSRC"
	@cd ${PKGJSONSDIR} && \
	for dir in `${FIND} . -type f -name package.json -exec dirname {} ';'`; do \
		for f in package.json yarn.lock; do \
			if [ -f ${WRKSRC}/$${dir}/$${f} ]; then \
				${MV} -f ${WRKSRC}/$${dir}/$${f} ${WRKSRC}/$${dir}/$${f}.bak; \
			fi; \
			${CP} -f $${dir}/$${f} ${WRKSRC}/$${dir}; \
		done; \
	done
	@${ECHO_MSG} "===>  Installing node modules from pre-fetched cache"
	@${ECHO_CMD} 'yarn-offline-mirror "../yarn-offline-cache"' >> ${WRKSRC}/.yarnrc
	@cd ${PKGJSONSDIR} && \
	for dir in `${FIND} . -type f -name package.json -exec dirname {} ';'`; do \
		cd ${WRKSRC}/$${dir} && ${SETENV} HOME=${WRKDIR} XDG_CACHE_HOME=${WRKDIR}/.cache \
			${YARN_CMD} --frozen-lockfile --ignore-scripts --offline; \
	done
.   endif
.endif # _ELECTRON_FEATURE_EXTRACT

.if defined(_ELECTRON_FEATURE_PREBUILD)
BUILD_DEPENDS+=	zip:archivers/zip
ZIP_CMD?=	${LOCALBASE}/bin/zip

BUILD_DEPENDS+= ${NODE_PKG_MANAGER}:${${NODE_PKG_MANAGER:tu}_PORTDIR}
.   if ${NODE_PKG_MANAGER} == yarn
BUILD_DEPENDS+=	npm:${NPM_PORTDIR}	# npm is needed for node-gyp
.   endif

MAKE_ENV+=	ELECTRON_SKIP_BINARY_DOWNLOAD=1 # effective electron >=6
MAKE_ENV+=	SASS_FORCE_BUILD=true		# always rebuild native node-sass module
MAKE_ENV+=	USE_SYSTEM_APP_BUILDER=true	# always use system app-builder for electron-builder
MAKE_ENV+=	XDG_CACHE_HOME=${WRKDIR}/.cache
MAKE_ENV+=	npm_config_build_from_source=true

.   if ${ELECTRON_VERSION} < 6
.	if !defined(UPSTREAM_ELECTRON_VER)
IGNORE=	does not specify the electron version used in the upstream source. Please refer to package-lock.json or yarn.lock for this value and set this appropriately.
.	endif
.   endif

_USES_build+=	490:electron-generate-electron-zip \
		491:electron-generate-chromedriver-zip \
		492:electron-rebuild-native-node-modules
electron-generate-electron-zip:
.   if ${ELECTRON_VERSION} < 6
	# This is only to pacify @electron/get and the zip file generated will
	# not be used for actual packaging.
	@${ECHO_MSG} "===>  Preparing distribution files of electron"
	@${RM} -r ${WRKDIR}/electron-dist
	@${MKDIR} ${WRKDIR}/electron-dist
	@cd ${LOCALBASE}/share/electron${ELECTRON_VERSION} && \
		${TAR} -cf - . | ${TAR} -xf - -C ${WRKDIR}/electron-dist
	@cd ${WRKDIR}/electron-dist && \
		${FIND} . -type f -perm ${BINMODE} -exec ${CHMOD} 755 {} ';'
	@${MKDIR} ${WRKDIR}/.cache/electron
	@cd ${WRKDIR}/electron-dist && \
		${ZIP_CMD} -q -r ${WRKDIR}/.cache/electron/electron-v${UPSTREAM_ELECTRON_VER}-freebsd-x64.zip .
	@cd ${WRKDIR}/.cache/electron && \
		${SHA256} -r electron-*.zip | \
		${SED} -e 's/ / */' > SHASUMS256.txt-${UPSTREAM_ELECTRON_VER}
.   else
	@${DO_NADA}
.   endif

electron-generate-chromedriver-zip:
.   if defined(UPSTREAM_CHROMEDRIVER_VER)
	@${ECHO_MSG} "===>  Preparing distribution files of chromedriver"
	@${RM} -r ${WRKDIR}/electron-dist
	@${MKDIR} ${WRKDIR}/electron-dist
	@cd ${LOCALBASE}/share/electron${ELECTRON_VERSION} && \
		${TAR} -cf - . | ${TAR} -xf - -C ${WRKDIR}/electron-dist
	@cd ${WRKDIR}/electron-dist && \
		${FIND} . -type f -perm ${BINMODE} -exec ${CHMOD} 755 {} ';'
	@${MKDIR} ${WRKDIR}/.cache/electron
	@cd ${WRKDIR}/electron-dist && \
		${ZIP_CMD} -q -r ${WRKDIR}/.cache/electron/chromedriver-v${UPSTREAM_CHROMEDRIVER_VER}-freebsd-x64.zip .
	@cd ${WRKDIR}/.cache/electron && \
		${SHA256} -r chromedriver-*.zip | \
		${SED} -e 's/ / */' > SHASUMS256.txt-${UPSTREAM_CHROMEDRIVER_VER}
.   else
	@${DO_NADA}
.   endif

electron-rebuild-native-node-modules:
	@${ECHO_MSG} "===>  Rebuilding native node modules for node"
	@cd ${PKGJSONSDIR} && \
	for dir in `${FIND} . -type f -name package.json -exec dirname {} ';'`; do \
		cd ${WRKSRC}/$${dir} && \
		${SETENV} ${MAKE_ENV} \
		npm_config_nodedir=${LOCALBASE} \
		${NPM_CMD} rebuild --no-progress; \
	done

.endif # _ELECTRON_FEATURE_PREBUILD
.endif # _INCLUDE_USES_ELECTRON_MK
