#!/bin/bash
# x86Sim sdkcov: build the SDK coverage app for each platform's arm64 simulator with swiftc (no Xcode project) into
# $X86SIM_SCRATCH/apps/sdkcov-<platform>.app (bundle id com.x86sim.test.sdkcov on all four).
# Usage: tests/apps/sdkcov/build.sh [ios] [tvos] [watchos] [xros]   (default: all four)
# Linux (build/linux-env.sh) or the Mac (X86SIM_BUILD=mac, over ssh), as tests/apps/build.sh.
# App extensions (sources in ext/, module sdkcov each, App Group group.com.x86sim.test.sdkcov): sdkcovWidget.appex
# (PlugIns/, WidgetKit: iOS, watchOS, visionOS), sdkcovFileProvider.appex (PlugIns/, File Provider: iOS, visionOS) and
# sdkcovExt.appex (Extensions/, ExtensionKit: iOS only) bound to the extension point the app defines in
# Extensions/sdkcov.appexpt (the file Xcode's exutil extract-extension-points makes from an AppExtensionPoint
# definition), sdkcovDownloader.appex (Extensions/, Background Assets: iOS, tvOS, visionOS; AssetPackManager traps in an
# app with BAAppGroupID and no downloader extension). checks/P3_Extensions.swift drives them.
# P10 (checks/P10_Extensions.swift), iOS: notification content + service extensions, a File Provider UI action, an SMS
# message filter, a call / message reporting (classification) UI and (P17) a Call Directory and an iMessage app extension in PlugIns/; a translation provider, an app
# migration, a Home, an accessory transport, an accessory data provider (AccessoryNotifications' notification
# forwarding) and a device discovery extension in Extensions/ (Apple's ExtensionKit points).
# visionOS: the notification content, File Provider UI action and reporting UI extensions (installd takes them there).
# P19, iOS and visionOS: a Quick Look preview extension (PlugIns/sdkcovQLPreview.appex) for the app's exported type
# com.x86sim.test.sdkcov.qlsample (*.sdkcovql).
# P22 (P23: all four platforms): a CryptoTokenKit persistent token extension (PlugIns/sdkcovToken.appex, class id com.x86sim.test.sdkcov.token).
# iOS also carries an App Clip, AppClips/sdkcovClip.app (ext/Clip.swift, bundle id com.x86sim.test.sdkcov.Clip): simctl /
# x86sim install of the app does not install it; run.sh and ref-mac.sh install it after the app.
# objc/SDKCovCatch.m: the app's one Objective-C file (an @try around a block), compiled with clang and imported into
# the Swift module through objc/SDKCovCatch.h.
set -e
X86SIM_ROOT=${X86SIM_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
. "$X86SIM_ROOT/build/mac-env.sh"
# SDKCOV_APPS: where the built .app goes (default $X86SIM_SCRATCH/apps); a private one lets parallel work (e.g. a git
# worktree per agent) build without replacing each other's app. run.sh / ref-mac.sh / inputs.sh read the same variable.
A=$X86SIM_ROOT/tests/apps; S=$A/sdkcov; OUT=${SDKCOV_APPS:-$X86SIM_SCRATCH/apps}; mkdir -p "$OUT"
# a bundle's Info.plist: plist_bundle FILE BUNDLE-ID EXECUTABLE PACKAGE-TYPE EXTRA-KEYS (the platform keys from the loop)
plist_bundle() {
	cat > "$1" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$2</string>
<key>CFBundleName</key><string>$3</string><key>CFBundleDisplayName</key><string>$3</string>
<key>CFBundleExecutable</key><string>$3</string><key>CFBundlePackageType</key><string>$4</string>
<key>CFBundleShortVersionString</key><string>1.0</string><key>CFBundleVersion</key><string>1</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>$plat</string></array>
<key>DTPlatformName</key><string>$sdk</string><key>MinimumOSVersion</key><string>27.0</string>
<key>UIDeviceFamily</key><array>$fam</array>
$5
</dict></plist>
PL
}
# an extension's entitlements (__TEXT,__entitlements, as for the app): its application id + the app's App Group
ents_ext() {
	cat > "$1" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
	<key>application-identifier</key><string>$2</string>
	<key>com.apple.security.get-task-allow</key><true/>
	<key>com.apple.security.application-groups</key><array><string>group.com.x86sim.test.sdkcov</string></array>$3
</dict></plist>
PL
}
# an NSExtension (PlugIns/) extension's NSExtension dictionary: nsext POINT PRINCIPAL-CLASS [ATTRIBUTES-DICT-BODY]
nsext() {
	echo "<key>NSExtension</key><dict><key>NSExtensionPointIdentifier</key><string>$1</string><key>NSExtensionPrincipalClass</key><string>$2</string>${3:+<key>NSExtensionAttributes</key><dict>$3</dict>}</dict>"
}
# an ExtensionKit (Extensions/) extension's attributes: exext POINT
exext() { echo "<key>EXAppExtensionAttributes</key><dict><key>EXExtensionPointIdentifier</key><string>$1</string></dict>"; }
BID=com.x86sim.test.sdkcov
# Background Assets (iOS, tvOS, visionOS): the App Group shared with the downloader extension (ext/Downloader.swift),
# Apple-hosted (managed) asset packs, and the initial download restrictions (the framework exits the app, "BUG IN
# CLIENT OF BackgroundAssets", when an asset-pack call finds no BAInitialDownloadRestrictions)
ba='
<key>BAHasManagedAssetPacks</key><true/><key>BAUsesAppleHosting</key><true/>
<key>BAInitialDownloadRestrictions</key><dict><key>BADownloadAllowance</key><integer>1048576</integer><key>BAEssentialDownloadAllowance</key><integer>1048576</integer><key>BADownloadDomainAllowList</key><array><string>example.com</string></array></dict>'
# NSApplicationServices (iOS, tvOS): the application service DeviceDiscoveryUI's picker browses for (its view aborts the
# app without an entry for the service, "Missing TCC info for browse")
appsvc='
<key>NSApplicationServices</key><dict><key>Browses</key><array><dict><key>NSApplicationServiceIdentifier</key><string>sdkcov</string><key>NSApplicationServiceUsageDescription</key><string>sdkcov checks the device picker</string></dict></array></dict>'
for p in ${*:-ios tvos watchos xros}; do
	multi='<false/>'
	# the extensions built for this platform (ext/*.swift, see the header)
	exts=
	case $p in
	# iPhone and iPad; on iPad all four orientations (iPad multitasking: Split View, Slide Over, Stage Manager windows need
	# them) and more than one scene (More_iPadOS.swift's multiple-window checks; one scene on iPhone either way)
	# NSSupportsLiveActivities: ActivityKit's Activity.request (refused without it); NSAlarmKitUsageDescription: AlarmKit's
	# authorization request (an app without it is refused); UIBackgroundModes voip: PushKit VoIP pushes.
	# NSAccessorySetupKitSupports (Bluetooth): AccessorySetupKit's session traps without it. Apple's iOS 27.2 simulator never
	# activates an ASAccessorySession (no activated event; deviceaccessd "GetDevices failed ... ENOENT") and the app dies
	# (SIGSEGV in AccessorySetupKit) when it invalidates the session, so func:AccessorySetupKit.session-activate keeps it
	ios) sdk=iphonesimulator; tgt=arm64-apple-ios27.0-simulator; plat=iPhoneSimulator; fam='<integer>1</integer><integer>2</integer>'; multi='<true/>'
		exts='widget fileprovider extkit downloader ncontent nservice fpaction msgfilter classify translator migration home transport dataprovider discovery clip docapp calldir imessage qlpreview token'
		extra='<key>UISupportedInterfaceOrientations~ipad</key><array><string>UIInterfaceOrientationPortrait</string><string>UIInterfaceOrientationPortraitUpsideDown</string><string>UIInterfaceOrientationLandscapeLeft</string><string>UIInterfaceOrientationLandscapeRight</string></array>
<key>NSSupportsLiveActivities</key><true/>
<key>NSHealthUpdateUsageDescription</key><string>sdkcov checks HealthKit writes</string>
<key>NSAlarmKitUsageDescription</key><string>sdkcov checks AlarmKit</string>
<key>UIBackgroundModes</key><array><string>voip</string></array>
<key>NSAccessorySetupKitSupports</key><array><string>Bluetooth</string></array>
<key>BAAppGroupID</key><string>group.com.x86sim.test.sdkcov</string>
<key>CFBundleURLTypes</key><array><dict><key>CFBundleURLName</key><string>com.x86sim.test.sdkcov</string><key>CFBundleURLSchemes</key><array><string>sdkcov</string></array></dict></array>'"$ba$appsvc" ;;
	tvos) sdk=appletvsimulator; tgt=arm64-apple-tvos27.0-simulator; plat=AppleTVSimulator; fam='<integer>3</integer>'; exts='downloader docapp token'  # no extkit: as watchOS below; docapp: the scene lifecycle round trip (P22)
		extra='<key>CFBundleURLTypes</key><array><dict><key>CFBundleURLName</key><string>com.x86sim.test.sdkcov</string><key>CFBundleURLSchemes</key><array><string>sdkcov</string></array></dict></array>
<key>BAAppGroupID</key><string>group.com.x86sim.test.sdkcov</string>'"$ba$appsvc" ;;
	# a standalone (watch-only) app: watchOS installs and runs it without an iPhone companion
	watchos) sdk=watchsimulator; tgt=arm64-apple-watchos27.0-simulator; plat=WatchSimulator; fam='<integer>4</integer>'
		# no ExtensionKit extension (tvOS, visionOS neither): their installd refuses an appex whose EXExtensionPointIdentifier is not one of
		# Apple's ("does not specify an Apple extension point"), so the app defines no extension point there either
		exts='widget token nservice'
		# WKBackgroundModes self-care: WKExtendedRuntimeSession runs (refused with error 7 without it); the Health usage
		# strings: the workout check may ask for Health access (an app without them is killed when it asks)
		extra='<key>WKApplication</key><true/><key>WKWatchOnly</key><true/><key>WKBackgroundModes</key><array><string>self-care</string></array><key>NSHealthShareUsageDescription</key><string>sdkcov reads workouts it saved</string><key>NSHealthUpdateUsageDescription</key><string>sdkcov saves a test workout</string>'
		# Xcode's watch SDK: the one in sdks/WatchSimulator.sdk is sim-sdk.py's substitute (macOS headers, no WatchKit)
		[ "$X86SIM_BUILD" = linux ] && export SDK_WATCHOS=$X86SIM_ROOT/sdks/WatchSimulator-xcode.sdk ;;
	# Xcode's visionOS SDK: sdks/XRSimulator.sdk is sim-sdk.py's substitute (iOS's framework list, not visionOS's)
	# NSWorldSensingUsageDescription / NSHandsTrackingUsageDescription: ARKit's plane detection / hand tracking
	# authorization (an app asking without them is killed)
	xros) sdk=xrsimulator; tgt=arm64-apple-xros27.0-simulator; plat=XRSimulator; fam='<integer>7</integer>'; multi='<true/>'  # volume + immersive spaces
		# docapp: the DocumentGroup companion app (P15) and the scene lifecycle round trip (P22), which come back by sdkcov:
		exts='widget fileprovider downloader ncontent nservice fpaction classify qlpreview docapp token'  # no extkit: as watchOS below
		extra='<key>CFBundleURLTypes</key><array><dict><key>CFBundleURLName</key><string>com.x86sim.test.sdkcov</string><key>CFBundleURLSchemes</key><array><string>sdkcov</string></array></dict></array>
<key>NSWorldSensingUsageDescription</key><string>sdkcov checks ARKit plane detection</string>
<key>NSHandsTrackingUsageDescription</key><string>sdkcov checks ARKit hand tracking</string>
<key>NSHealthUpdateUsageDescription</key><string>sdkcov checks HealthKit writes</string>
<key>BAAppGroupID</key><string>group.com.x86sim.test.sdkcov</string>'"$ba"
		[ "$X86SIM_BUILD" = linux ] && export SDK_XROS=$X86SIM_ROOT/sdks/XRSimulator-xcode.sdk ;;
	*) echo "sdkcov build: unknown platform $p (ios, tvos, watchos, xros)" >&2; exit 2 ;;
	esac
	[ -f "$S/manifest-$p.json" ] || { echo "sdkcov build: no manifest-$p.json (gen-manifest.py $p)" >&2; exit 1; }
	echo "== sdkcov $p" >&2
	# the generated plists (app, extensions, extension point, entitlements) go to the build in gen/
	G=$(mktemp -d /tmp/sdkcov-gen.XXXXXX); mkdir -p "$G/gen"
	plist_bundle "$G/gen/app.plist" $BID sdkcov APPL "<key>UILaunchScreen</key><dict/>
<key>UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key>$multi</dict>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
<key>BGTaskSchedulerPermittedIdentifiers</key><array><string>com.x86sim.test.sdkcov.refresh</string></array>
<key>NSUserActivityTypes</key><array><string>com.x86sim.test.sdkcov.activity</string></array>
<key>NSLocationWhenInUseUsageDescription</key><string>sdkcov checks Core Location</string>
<key>NSContactsUsageDescription</key><string>sdkcov checks Contacts</string>
<key>NSCalendarsFullAccessUsageDescription</key><string>sdkcov checks EventKit</string>
<key>NSPhotoLibraryUsageDescription</key><string>sdkcov checks Photos</string>
<key>NSMicrophoneUsageDescription</key><string>sdkcov checks audio input</string>
<key>NSSpeechRecognitionUsageDescription</key><string>sdkcov checks Speech</string>
<key>NSHealthShareUsageDescription</key><string>sdkcov checks HealthKit</string>
<key>NSHomeKitUsageDescription</key><string>sdkcov checks HomeKit</string>
<key>NSMotionUsageDescription</key><string>sdkcov checks Core Motion</string>
<key>NSFaceIDUsageDescription</key><string>sdkcov checks biometrics</string>
<key>NSBluetoothAlwaysUsageDescription</key><string>sdkcov checks Core Bluetooth</string>
<key>NSLocalNetworkUsageDescription</key><string>sdkcov checks Network on loopback</string>
<key>NSAppleMusicUsageDescription</key><string>sdkcov checks the media library and Apple Music</string>
<key>NSVideoSubscriberAccountUsageDescription</key><string>sdkcov checks the TV provider account</string>
<key>NSBonjourServices</key><array><string>_sdkcov._tcp</string></array>
<key>UTExportedTypeDeclarations</key><array><dict><key>UTTypeIdentifier</key><string>com.x86sim.test.sdkcov.qlsample</string>
<key>UTTypeDescription</key><string>sdkcov Quick Look sample</string><key>UTTypeConformsTo</key><array><string>public.data</string><string>public.content</string></array>
<key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>sdkcovql</string></array></dict></dict></array>
$extra"
	# the watch's NSHealthShareUsageDescription is in $extra: one copy (plutil rejects a duplicate key)
	[ $p = watchos ] && python3 -I - "$G/gen/app.plist" <<'PY'
import sys, re
s = open(sys.argv[1]).read()
k = '<key>NSHealthShareUsageDescription</key><string>sdkcov checks HealthKit</string>\n'
open(sys.argv[1], 'w').write(s.replace(k, '', 1))
PY
	for e in $exts; do case $e in
		widget) plist_bundle "$G/gen/widget.plist" $BID.widget sdkcovWidget 'XPC!' '<key>NSExtension</key><dict><key>NSExtensionPointIdentifier</key><string>com.apple.widgetkit-extension</string></dict>'
			ents_ext "$G/gen/widget.entitlements" $BID.widget ;;
		fileprovider) plist_bundle "$G/gen/fileprovider.plist" $BID.fileprovider sdkcovFileProvider 'XPC!' '<key>NSExtension</key><dict>
<key>NSExtensionPointIdentifier</key><string>com.apple.fileprovider-nonui</string>
<key>NSExtensionPrincipalClass</key><string>SDKCovFileProvider</string>
<key>NSExtensionFileProviderSupportsEnumeration</key><true/>
<key>NSExtensionFileProviderDocumentGroup</key><string>group.com.x86sim.test.sdkcov</string></dict>'
			ents_ext "$G/gen/fileprovider.entitlements" $BID.fileprovider ;;
		# P10 (iOS)
		ncontent) plist_bundle "$G/gen/ncontent.plist" $BID.ncontent sdkcovNotifyContent 'XPC!' "$(nsext com.apple.usernotifications.content-extension SDKCovNotificationContent '<key>UNNotificationExtensionCategory</key><string>sdkcov.content</string><key>UNNotificationExtensionInitialContentSizeRatio</key><real>0.5</real>')"
			ents_ext "$G/gen/ncontent.entitlements" $BID.ncontent ;;
		nservice) plist_bundle "$G/gen/nservice.plist" $BID.nservice sdkcovNotifyService 'XPC!' "$(nsext com.apple.usernotifications.service SDKCovNotificationService)"
			ents_ext "$G/gen/nservice.entitlements" $BID.nservice ;;
		fpaction) plist_bundle "$G/gen/fpaction.plist" $BID.fpaction sdkcovFPAction 'XPC!' "$(nsext com.apple.fileprovider-actionsui SDKCovFPAction '<key>NSExtensionFileProviderActions</key><array><dict><key>NSExtensionFileProviderActionIdentifier</key><string>com.x86sim.test.sdkcov.action</string><key>NSExtensionFileProviderActionName</key><string>sdkcov action</string><key>NSExtensionFileProviderActionActivationRule</key><string>TRUEPREDICATE</string></dict></array>')"
			ents_ext "$G/gen/fpaction.entitlements" $BID.fpaction ;;
		# a persistent token extension (ext/Token.swift): CryptoTokenKit's TKTokenDriver.Configuration from the app
		token) plist_bundle "$G/gen/token.plist" $BID.token sdkcovToken 'XPC!' "$(nsext com.apple.ctk-tokens SDKCovTokenDriver '<key>com.apple.ctk.class-id</key><string>com.x86sim.test.sdkcov.token</string><key>com.apple.ctk.driver-class</key><string>SDKCovTokenDriver</string><key>com.apple.ctk.token-type</key><string>persistent</string>')"
			ents_ext "$G/gen/token.entitlements" $BID.token ;;
		msgfilter) plist_bundle "$G/gen/msgfilter.plist" $BID.msgfilter sdkcovMessageFilter 'XPC!' "$(nsext com.apple.identitylookup.message-filter SDKCovMessageFilter)"
			ents_ext "$G/gen/msgfilter.entitlements" $BID.msgfilter ;;
		imessage) plist_bundle "$G/gen/imessage.plist" $BID.imessage sdkcovMessages 'XPC!' "$(nsext com.apple.message-payload-provider SDKCovMessagesVC)"
			ents_ext "$G/gen/imessage.entitlements" $BID.imessage ;;
		# (P19) a Quick Look preview extension for the app's own document type (UTExportedTypeDeclarations below)
		qlpreview) plist_bundle "$G/gen/qlpreview.plist" $BID.qlpreview sdkcovQLPreview 'XPC!' "$(nsext com.apple.quicklook.preview SDKCovQLPreview '<key>QLSupportedContentTypes</key><array><string>com.x86sim.test.sdkcov.qlsample</string></array><key>QLSupportsSearchableItems</key><false/>')"
			ents_ext "$G/gen/qlpreview.entitlements" $BID.qlpreview ;;
		calldir) plist_bundle "$G/gen/calldir.plist" $BID.calldir sdkcovCallDirectory 'XPC!' "$(nsext com.apple.callkit.call-directory SDKCovCallDirectory)"
			ents_ext "$G/gen/calldir.entitlements" $BID.calldir ;;
		classify) plist_bundle "$G/gen/classify.plist" $BID.classify sdkcovClassification 'XPC!' "$(nsext com.apple.identitylookup.classification-ui SDKCovClassification '<key>ILClassificationExtensionSMSReportDestination</key><string>12345</string>')"
			ents_ext "$G/gen/classify.entitlements" $BID.classify ;;
		translator) plist_bundle "$G/gen/translator.plist" $BID.translator sdkcovTranslator 'XPC!' "$(exext com.apple.public.translation-ui-provider)"
			ents_ext "$G/gen/translator.entitlements" $BID.translator ;;
		migration) plist_bundle "$G/gen/migration.plist" $BID.migration sdkcovMigration 'XPC!' "$(exext com.apple.app-migration)"
			ents_ext "$G/gen/migration.entitlements" $BID.migration ;;
		home) plist_bundle "$G/gen/home.plist" $BID.home sdkcovHome 'XPC!' "$(exext com.apple.Home.HomeExtension)"
			ents_ext "$G/gen/home.entitlements" $BID.home '<key>com.apple.developer.home</key><true/>' ;;
		# the developer entitlements the extension points require (installd refuses the app without them)
		transport) plist_bundle "$G/gen/transport.plist" $BID.transport sdkcovTransport 'XPC!' "$(exext com.apple.accessory-transport-extension)"
			ents_ext "$G/gen/transport.entitlements" $BID.transport '<key>com.apple.developer.accessory-transport-extension</key><true/>' ;;
		# the accessory data provider's capability (AccessoryNotifications' NotificationsForwarding) as Xcode's exutil
		# generate-appextension-plist writes it from the extension's @AppExtensionPoint.Bind
		dataprovider) plist_bundle "$G/gen/dataprovider.plist" $BID.dataprovider sdkcovDataProvider 'XPC!' '<key>EXAppExtensionAttributes</key><dict><key>EXCapabilities</key><array><string>AccessoryNotifications.NotificationsForwarding</string></array><key>EXExtensionPointIdentifier</key><string>com.apple.accessory-data-provider</string></dict>'
			ents_ext "$G/gen/dataprovider.entitlements" $BID.dataprovider '<key>com.apple.developer.accessory-data-provider</key><true/>' ;;
		discovery) plist_bundle "$G/gen/discovery.plist" $BID.discovery sdkcovDiscovery 'XPC!' "$(exext com.apple.discovery-extension)"
			ents_ext "$G/gen/discovery.entitlements" $BID.discovery '<key>com.apple.developer.media-device-discovery-extension</key><true/>' ;;
		# the App Clip: an app (AppClips/) whose parent is the sdkcov app
		clip) plist_bundle "$G/gen/clip.plist" $BID.Clip sdkcovClip APPL '<key>UILaunchScreen</key><dict/><key>NSAppClip</key><dict><key>NSAppClipRequestEphemeralUserNotification</key><false/><key>NSAppClipRequestLocationConfirmation</key><false/></dict>'
			ents_ext "$G/gen/clip.entitlements" $BID.Clip "<key>com.apple.developer.parent-application-identifiers</key><array><string>$BID</string></array><key>com.apple.developer.on-demand-install-capable</key><true/>" ;;
		# the DocumentGroup companion app (ext/DocApp.swift), installed next to the app (run.sh, ref-mac.sh): a plain-text
		# document type it edits in place, opened by sdkcov through its URL scheme sdkcovdoc:
		docapp) plist_bundle "$G/gen/docapp.plist" $BID.doc sdkcovDoc APPL '<key>UILaunchScreen</key><dict/>
<key>UISupportsDocumentBrowser</key><true/><key>LSSupportsOpeningDocumentsInPlace</key><true/>
<key>UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key><true/></dict>
<key>CFBundleDocumentTypes</key><array><dict><key>CFBundleTypeName</key><string>Text</string><key>CFBundleTypeRole</key><string>Editor</string><key>LSHandlerRank</key><string>Alternate</string><key>LSItemContentTypes</key><array><string>public.plain-text</string></array></dict></array>
<key>CFBundleURLTypes</key><array><dict><key>CFBundleURLName</key><string>com.x86sim.test.sdkcov.doc</string><key>CFBundleURLSchemes</key><array><string>sdkcovdoc</string></array></dict></array>'
			ents_ext "$G/gen/docapp.entitlements" $BID.doc ;;
		downloader) plist_bundle "$G/gen/downloader.plist" $BID.downloader sdkcovDownloader 'XPC!' '<key>EXAppExtensionAttributes</key><dict><key>EXExtensionPointIdentifier</key><string>com.apple.background-asset-downloader-extension</string></dict>'
			ents_ext "$G/gen/downloader.entitlements" $BID.downloader ;;
		extkit) plist_bundle "$G/gen/extkit.plist" $BID.ext sdkcovExt 'XPC!' '<key>EXAppExtensionAttributes</key><dict><key>EXExtensionPointIdentifier</key><string>com.x86sim.test.sdkcov.sdkcov-ext</string></dict>'
			ents_ext "$G/gen/extkit.entitlements" $BID.ext
			# the extension point (exutil's output for AppExtensionPoint.Definition { Name("sdkcov-ext"); UserInterface() }):
			# a user interface (an EXHostViewController scene) on iOS only (UserInterface is iOS / macOS API)
			ui='<false/>'; [ $p = ios ] && ui='<true/>'
			cat > "$G/gen/sdkcov.appexpt" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
	<key>com.x86sim.test.sdkcov.sdkcov-ext</key><dict>
		<key>EXExtensionPointName</key><string>sdkcov-ext</string>
		<key>EXPresentsUserInterface</key>$ui
		<key>EXRequiresEnhancedSecurity</key><false/>
	</dict>
	<key>EXVersion</key><integer>2</integer>
</dict></plist>
PL
			;;
	esac; done
	tar cf - -C "$A" common.swift sdkcov -C "$G" gen | mac "set -e; W=\$(mktemp -d /tmp/sdkcov.XXXXXX); cd \$W; tar xf -
		APP=sdkcov-$p.app; mkdir -p \$APP
		nice xcrun -sdk $sdk clang -target $tgt -fobjc-arc -O0 -c sdkcov/objc/SDKCovCatch.m -o catch.o
		nice xcrun -sdk $sdk swiftc -target $tgt -Onone -parse-as-library -module-name sdkcov -import-objc-header sdkcov/objc/SDKCovCatch.h catch.o \
			-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __entitlements -Xlinker sdkcov/sdkcov.entitlements \
			-o \$APP/sdkcov common.swift sdkcov/*.swift sdkcov/checks/*.swift 2>&1 >&2 | grep -v 'directory not found for option -L' >&2 || true
		test -x \$APP/sdkcov
		cp sdkcov/manifest-$p.json \$APP/manifest.json
		cp gen/app.plist \$APP/Info.plist
		# bundle resources (res/): sdkcovGK.sks, a SpriteKit scene with a GameplayKit GKScene (res/sdkcovGK.swift made it on
		# the Mac, the archive Xcode's scene editor writes: root + _gkScene) for func:GameplayKit.gkscene-from-sks;
		# sdkcovChapters.mov / sdkcovStall.mov (res/sdkcovMovies.swift on the Mac) for checks/P22_Gaps.swift's watchOS-capable AVFoundation checks
		cp sdkcov/res/*.sks sdkcov/res/*.mov \$APP/
		# sdkcovCI.metallib: the platform's stitchable Core Image kernels (res/sdkcovCI.sh: Apple's Metal toolchain under Darling)
		# sdkcovHLS.url: a YouTube HLS master playlist URL for func:AVFoundation.hls-remote-youtube (signed, expires: not in git)
		if [ -f sdkcov/res/sdkcovHLS.url ]; then cp sdkcov/res/sdkcovHLS.url \$APP/; fi
		if [ -f sdkcov/res/sdkcovCI-$p.metallib ]; then cp sdkcov/res/sdkcovCI-$p.metallib \$APP/sdkcovCI.metallib; fi
		# extensions: ext NAME DIR SOURCE GEN (GEN: its gen/ plist + entitlements). The entry point is Foundation's _NSExtensionMain, as Xcode links every
		# extension (ExtensionKit's and WidgetKit's @main types are found and run from there: entered through their own
		# main, ExtensionFoundation traps on its unset _EXRunningExtension)
		ext() { n=\$1 d=\$2 src=\$3 g=\$4; X=\$APP/\$d/sdkcov\$n.appex
			mkdir -p \$X
			nice xcrun -sdk $sdk swiftc -target $tgt -Onone -parse-as-library -application-extension -module-name sdkcov \
				-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __entitlements -Xlinker gen/\$g.entitlements -Xlinker -e -Xlinker _NSExtensionMain \
				-o \$X/sdkcov\$n sdkcov/ext/Marks.swift sdkcov/ext/\$src 2>&1 >&2 | grep -v 'directory not found for option -L' >&2 || true
			test -x \$X/sdkcov\$n
			cp gen/\$g.plist \$X/Info.plist
			codesign -f -s - --entitlements sdkcov/sign.entitlements \$X >&2
		}
		for e in $exts; do case \$e in
			widget) ext Widget PlugIns Widget.swift widget ;;
			fileprovider) ext FileProvider PlugIns FileProvider.swift fileprovider ;;
			extkit) ext Ext Extensions ExtKit.swift extkit; cp gen/sdkcov.appexpt \$APP/Extensions/ ;;
			downloader) ext Downloader Extensions Downloader.swift downloader ;;
			ncontent) ext NotifyContent PlugIns NotifyContent.swift ncontent ;;
			nservice) ext NotifyService PlugIns NotifyService.swift nservice ;;
			fpaction) ext FPAction PlugIns FPAction.swift fpaction ;;
			msgfilter) ext MessageFilter PlugIns MessageFilter.swift msgfilter ;;
			token) ext Token PlugIns Token.swift token ;;
			classify) ext Classification PlugIns Classification.swift classify ;;
			calldir) ext CallDirectory PlugIns CallDirectory.swift calldir ;;
			qlpreview) ext QLPreview PlugIns QLPreview.swift qlpreview ;;
			imessage) ext Messages PlugIns Messages.swift imessage ;;
			translator) ext Translator Extensions Translator.swift translator ;;
			migration) ext Migration Extensions Migration.swift migration ;;
			home) ext Home Extensions HomeExt.swift home ;;
			transport) ext Transport Extensions Transport.swift transport ;;
			dataprovider) ext DataProvider Extensions DataProvider.swift dataprovider ;;
			discovery) ext Discovery Extensions Discovery.swift discovery ;;
			clip) X=\$APP/AppClips/sdkcovClip.app; mkdir -p \$X
				nice xcrun -sdk $sdk swiftc -target $tgt -Onone -parse-as-library -module-name sdkcov \
					-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __entitlements -Xlinker gen/clip.entitlements \
					-o \$X/sdkcovClip sdkcov/ext/Marks.swift sdkcov/ext/Clip.swift 2>&1 >&2 | grep -v 'directory not found for option -L' >&2 || true
				test -x \$X/sdkcovClip
				cp gen/clip.plist \$X/Info.plist
				codesign -f -s - --entitlements sdkcov/sign.entitlements \$X >&2 ;;
			docapp) X=sdkcovDoc-$p.app; mkdir -p \$X
				nice xcrun -sdk $sdk swiftc -target $tgt -Onone -parse-as-library -module-name sdkcov \
					-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __entitlements -Xlinker gen/docapp.entitlements \
					-o \$X/sdkcovDoc sdkcov/ext/Marks.swift sdkcov/ext/DocApp.swift 2>&1 >&2 | grep -v 'directory not found for option -L' >&2 || true
				test -x \$X/sdkcovDoc
				cp gen/docapp.plist \$X/Info.plist
				codesign -f -s - --entitlements sdkcov/sign.entitlements \$X >&2 ;;
		esac; done
		codesign -f -s - --entitlements sdkcov/sign.entitlements \$APP >&2
		tar cf - \$APP \$(ls -d sdkcovDoc-$p.app 2>/dev/null); cd /; rm -rf \$W" | (cd "$OUT" && rm -rf "sdkcov-$p.app" "sdkcovDoc-$p.app" && tar xf -)
	rm -rf "$G"
	ls -d "$OUT/sdkcov-$p.app"
done
