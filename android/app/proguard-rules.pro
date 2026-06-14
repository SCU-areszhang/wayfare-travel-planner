# AMap 3D map loads several AutoNavi classes from native code by their original
# Java names. R8 cannot see those references, so keep the SDK packages intact.
-keep class com.amap.** { *; }
-keep class com.autonavi.** { *; }
-keep class com.loc.** { *; }

-dontwarn com.amap.**
-dontwarn com.autonavi.**
-dontwarn com.loc.**
