--- electron/script/lib/utils.js.orig	2019-05-16 04:03:34 UTC
+++ electron/script/lib/utils.js
@@ -14,6 +14,7 @@ function getElectronExec () {
     case 'win32':
       return `out/${OUT_DIR}/electron.exe`
     case 'linux':
+    case 'freebsd':
       return `out/${OUT_DIR}/electron`
     default:
       throw new Error('Unknown platform')