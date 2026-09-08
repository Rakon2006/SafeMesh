#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(SafeMeshNativePlugin, "SafeMeshNative",
    CAP_PLUGIN_METHOD(getEmergencyState, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(activateSOS, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(deactivateSOS, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(getPermissionStatus, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(openSettings, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(call112, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(callEmergencyContact, CAPPluginReturnPromise);
)
