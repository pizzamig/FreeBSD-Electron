--- chrome/browser/media/webrtc/webrtc_logging_handler_host.cc.orig	2019-04-08 08:32:44 UTC
+++ chrome/browser/media/webrtc/webrtc_logging_handler_host.cc
@@ -26,10 +26,10 @@
 #include "content/public/browser/content_browser_client.h"
 #include "content/public/browser/render_process_host.h"
 
-#if defined(OS_LINUX) || defined(OS_CHROMEOS)
+#if defined(OS_LINUX) || defined(OS_CHROMEOS) || defined(OS_BSD)
 #include "content/public/browser/child_process_security_policy.h"
 #include "storage/browser/fileapi/isolated_context.h"
-#endif  // defined(OS_LINUX) || defined(OS_CHROMEOS)
+#endif  // defined(OS_LINUX) || defined(OS_CHROMEOS) || defined(OS_BSD)
 
 using content::BrowserThread;
 using webrtc_event_logging::WebRtcEventLogManager;
@@ -281,7 +281,7 @@ void WebRtcLoggingHandlerHost::StartEventLogging(
       output_period_ms, web_app_id, callback);
 }
 
-#if defined(OS_LINUX) || defined(OS_CHROMEOS)
+#if defined(OS_LINUX) || defined(OS_CHROMEOS) || defined(OS_BSD)
 void WebRtcLoggingHandlerHost::GetLogsDirectory(
     const LogsDirectoryCallback& callback,
     const LogsDirectoryErrorCallback& error_callback) {
@@ -327,7 +327,7 @@ void WebRtcLoggingHandlerHost::GrantLogsDirectoryAcces
       FROM_HERE, {BrowserThread::UI},
       base::BindOnce(callback, filesystem_id, registered_name));
 }
-#endif  // defined(OS_LINUX) || defined(OS_CHROMEOS)
+#endif  // defined(OS_LINUX) || defined(OS_CHROMEOS) || defined(OS_BSD
 
 void WebRtcLoggingHandlerHost::OnRtpPacket(
     std::unique_ptr<uint8_t[]> packet_header,
