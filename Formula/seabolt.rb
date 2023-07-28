class Seabolt < Formula
  desc "Neo4j Bolt Connector for C"
  homepage "https://github.com/neo4j-drivers/seabolt"
  url "https://github.com/neo4j-drivers/seabolt/archive/v1.7.4.tar.gz"
  sha256 "f51c02dfef862d97963a7b67b670750730fcdd7b56a11ce87c8c1d01826397ee"

  depends_on "cmake" => :build
  depends_on "pkg-config"
  depends_on "openssl" => [:build, :test]

  patch :DATA if MacOS.version == :monterey || MacOS.version == :big_sur || MacOS.version == :mojave || MacOS.version == :catalina

  def install
    system "mkdir", "build"
    Dir.chdir('build')
    system "cmake", "..", *std_cmake_args
    system "cmake", "--build", ".", "--target", "install"
    
    bin.install "bin/seabolt-cli"
  end

  test do
    require "open3"
    Open3.popen3("BOLT_USER= #{bin}/seabolt-cli run \"UNWIND range(1, 3) AS n RETURN n\"") do |_, _, stderr|
      assert_equal "FATAL: Failed to connect", stderr.read.strip
    end
  end
end

__END__
diff --git a/src/seabolt-cli/src/main.c b/src/seabolt-cli/src/main.c
index 41204c2..6c7db84 100644
--- a/src/seabolt-cli/src/main.c
+++ b/src/seabolt-cli/src/main.c
@@ -43,20 +43,25 @@
 #ifdef __APPLE__
 #include <mach/clock.h>
 #include <mach/mach.h>
-
-#define TIME_UTC 0
-
-void timespec_get(struct timespec *ts, int type)
-{
-    UNUSED(type);
-    clock_serv_t cclock;
-    mach_timespec_t mts;
-    host_get_clock_service(mach_host_self(), CALENDAR_CLOCK, &cclock);
-    clock_get_time(cclock, &mts);
-    mach_port_deallocate(mach_task_self(), cclock);
-    ts->tv_sec = mts.tv_sec;
-    ts->tv_nsec = mts.tv_nsec;
-}
+#include <Availability.h>
+
+#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED
+    #if __MAC_OS_X_VERSION_MIN_REQUIRED < 10153
+        #define TIME_UTC 0
+
+        int timespec_get(struct timespec *ts, int type)
+        {
+            UNUSED(type);
+            clock_serv_t cclock;
+            mach_timespec_t mts;
+            host_get_clock_service(mach_host_self(), CALENDAR_CLOCK, &cclock);
+            clock_get_time(cclock, &mts);
+            mach_port_deallocate(mach_task_self(), cclock);
+            ts->tv_sec = mts.tv_sec;
+            ts->tv_nsec = mts.tv_nsec;
+        }
+    #endif
+#endif
 #endif
 
 enum Command {
diff --git a/src/common/tests/catch.hpp b/src/common/tests/catch.hpp
index 52201a3..30d6cd7 100644
--- a/src/common/tests/catch.hpp
+++ b/src/common/tests/catch.hpp
@@ -1368,7 +1368,18 @@ namespace Catch {

 #ifdef CATCH_PLATFORM_MAC

-    #define CATCH_TRAP() __asm__("int $3\n" : : ) /* NOLINT */
+    #if defined(__ppc64__) || defined(__ppc__)
+        #define CATCH_TRAP() \
+                __asm__("li r0, 20\nsc\nnop\nli r0, 37\nli r4, 2\nsc\nnop\n" \
+                : : : "memory","r0","r3","r4" )
+    // backported from Catch2
+    // revision b9853b4b356b83bb580c746c3a1f11101f9af54f
+    // src/catch2/internal/catch_debugger.hpp
+    #elif defined(__i386__) || defined(__x86_64__)
+        #define CATCH_TRAP() __asm__("int $3\n" : : ) /* NOLINT */
+    #elif defined(__aarch64__)
+        #define CATCH_TRAP()  __asm__(".inst 0xd4200000")
+    #endif

 #elif defined(CATCH_PLATFORM_LINUX)
     // If we can use inline assembler, do it because this allows us to break
