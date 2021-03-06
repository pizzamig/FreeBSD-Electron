--- electron/spec-main/api-net-log-spec.js.orig	2019-12-13 19:48:14 UTC
+++ electron/spec-main/api-net-log-spec.js
@@ -123,7 +123,7 @@ describe('netLog module', () => {
   })
 
   it('should begin and end logging automatically when --log-net-log is passed', done => {
-    if (isCI && process.platform === 'linux') {
+    if (isCI && (process.platform === 'linux' || process.platform === 'freebsd')) {
       done()
       return
     }
@@ -143,7 +143,7 @@ describe('netLog module', () => {
   })
 
   it('should begin and end logging automtically when --log-net-log is passed, and behave correctly when .startLogging() and .stopLogging() is called', done => {
-    if (isCI && process.platform === 'linux') {
+    if (isCI && (process.platform === 'linux' || process.platform === 'freebsd')) {
       done()
       return
     }
@@ -166,7 +166,7 @@ describe('netLog module', () => {
   })
 
   it('should end logging automatically when only .startLogging() is called', done => {
-    if (isCI && process.platform === 'linux') {
+    if (isCI && (process.platform === 'linux' || process.platform === 'freebsd')) {
       done()
       return
     }
