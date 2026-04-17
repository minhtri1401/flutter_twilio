#import "FlutterTwilioPlugin.h"
#if __has_include(<flutter_twilio/flutter_twilio-Swift.h>)
#import <flutter_twilio/flutter_twilio-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_twilio-Swift.h"
#endif

@implementation FlutterTwilioPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [FlutterTwilioPlugin registerWithRegistrar:registrar];
}
@end
