@import Foundation;

#ifndef __XPC_H__
// Types
typedef NSObject* xpc_object_t;
typedef xpc_object_t xpc_connection_t;
typedef void (^xpc_handler_t)(xpc_object_t object);

// Communication
extern xpc_connection_t xpc_connection_create_mach_service(const char* name, dispatch_queue_t targetq, uint64_t flags);
extern void xpc_connection_set_event_handler(xpc_connection_t connection, xpc_handler_t handler);
extern void xpc_connection_resume(xpc_connection_t connection);
extern void xpc_connection_send_message_with_reply(xpc_connection_t connection, xpc_object_t message, dispatch_queue_t replyq, xpc_handler_t handler);
extern xpc_object_t xpc_connection_send_message_with_reply_sync(xpc_connection_t connection, xpc_object_t message);
extern xpc_object_t xpc_dictionary_get_value(xpc_object_t xdict, const char *key);
#endif

// Serialization
extern CFTypeRef _CFXPCCreateCFObjectFromXPCObject(xpc_object_t xpcattrs);
extern xpc_object_t _CFXPCCreateXPCObjectFromCFObject(CFTypeRef attrs);
extern xpc_object_t _CFXPCCreateXPCMessageWithCFObject(CFTypeRef obj);
extern CFTypeRef _CFXPCCreateCFObjectFromXPCMessage(xpc_object_t obj);


typedef enum {
    kAMFIActionArm = 0,     // Trigger a prompt asking the user to enable developer mode on the next reboot
                            // (regardless of current state)
    kAMFIActionDisable = 1, // Disable developer mode if it's currently enabled. Takes effect immediately.
    kAMFIActionStatus = 2,  // Returns a dict: {success: bool, status: bool, armed: bool}
} AMFIXPCAction;

xpc_connection_t startConnection(void) {
	xpc_connection_t connection = xpc_connection_create_mach_service("com.apple.amfi.xpc", NULL, 0);
    if (!connection) {
        NSLog(@"[startXPCConnection] Failed to create XPC connection to amfid");
        return nil;
    }
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
    });
    xpc_connection_resume(connection);
    return connection;
}

NSDictionary* sendXPCRequest(xpc_connection_t connection, AMFIXPCAction action) {
    xpc_object_t message = _CFXPCCreateXPCMessageWithCFObject((__bridge CFDictionaryRef) @{@"action": @(action)});
    xpc_object_t replyMsg = xpc_connection_send_message_with_reply_sync(connection, message);
    if (!replyMsg) {
        NSLog(@"[sendXPCRequest] got no reply from amfid");
        return nil;
    }

    xpc_object_t replyObj = xpc_dictionary_get_value(replyMsg, "cfreply");
    if (!replyObj) {
        NSLog(@"[sendXPCRequest] got reply but no cfreply");
        return nil;
    }

    NSDictionary* asCF = (__bridge NSDictionary*)_CFXPCCreateCFObjectFromXPCMessage(replyObj);
    return asCF;
}

BOOL getDeveloperModeState(xpc_connection_t connection) {
    NSDictionary* reply = sendXPCRequest(connection, kAMFIActionStatus);
    if (!reply) {
        NSLog(@"[getDeveloperModeState] failed to get reply");
        return NO;
    }

    NSLog(@"[getDeveloperModeState] got reply %@", reply);

    NSObject* success = reply[@"success"];
    if (!success || ![success isKindOfClass:[NSNumber class]] || ![(NSNumber*)success boolValue]) {
        NSLog(@"[getDeveloperModeState] request failed with error %@", reply[@"error"]);
        return NO;
    }

    NSObject* status = reply[@"status"];
    if (!status || ![status isKindOfClass:[NSNumber class]]) {
        NSLog(@"[getDeveloperModeState] request succeeded but no status");
        return NO;
    }

    return [(NSNumber*)status boolValue];
}

BOOL setDeveloperModeState(xpc_connection_t connection, BOOL enable) {
    NSDictionary* reply = sendXPCRequest(connection, enable ? kAMFIActionArm : kAMFIActionDisable);
    if (!reply) {
        NSLog(@"[setDeveloperModeState] failed to get reply");
        return NO;
    }

    NSObject* success = reply[@"success"];
    if (!success || ![success isKindOfClass:[NSNumber class]] || ![(NSNumber*)success boolValue]) {
        NSLog(@"[setDeveloperModeState] request failed with error %@", reply[@"error"]);
        return NO;
    }

    return YES;
}

BOOL checkDeveloperMode(void) {
    // Developer mode does not exist before iOS 16
    if (@available(iOS 16, *)) {
        xpc_connection_t connection = startConnection();
        if (!connection) {
            NSLog(@"[checkDeveloperMode] failed to start connection");
            // Assume it's disabled
            return NO;
        }

        return getDeveloperModeState(connection);
    } else {
        return YES;
    }
}

BOOL armDeveloperMode(BOOL* alreadyEnabled) {
    // Developer mode does not exist before iOS 16
    if (@available(iOS 16, *)) {
        xpc_connection_t connection = startConnection();
        if (!connection) {
            NSLog(@"[armDeveloperMode] failed to start connection");
            return NO;
        }

        BOOL enabled = getDeveloperModeState(connection);
        if (alreadyEnabled) {
            *alreadyEnabled = enabled;
        }

        if (enabled) {
            // NSLog(@"[armDeveloperMode] already enabled");
            return YES;
        }

        BOOL success = setDeveloperModeState(connection, YES);
        if (!success) {
            NSLog(@"[armDeveloperMode] failed to arm");
            return NO;
        }
    }

    return YES;
}
