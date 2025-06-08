#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <xpc/xpc.h>
#include <stdio.h>
#include <string.h>
#include <os/log.h>
#include <errno.h>

// Global logger - properly declared
static os_log_t logger = NULL;

// Updated to return int instead of void
int scheduleSleepIOKit(void) {
    os_log_info(logger, "Attempting to put display to sleep");
    
    io_registry_entry_t rootDomain = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/IOResources/IODisplayWrangler");
    if (!rootDomain) {
        os_log_error(logger, "Failed to get IODisplayWrangler");
        return -1;
    }
    
    kern_return_t result = IORegistryEntrySetCFProperty(rootDomain, CFSTR("IORequestIdle"), kCFBooleanTrue);
    IOObjectRelease(rootDomain);
    
    if (result != KERN_SUCCESS) {
        os_log_error(logger, "Failed to request display sleep: 0x%x", result);
        return -1;
    }
    
    os_log_info(logger, "Display sleep requested successfully");
    return 0;
}

int scheduleWakeIOKit(int secondsFromNow) {
    os_log_info(logger, "Attempting to schedule wake in %d seconds", secondsFromNow);
    
    if (secondsFromNow <= 0) {
        os_log_error(logger, "Invalid wake time: %d seconds", secondsFromNow);
        return -EINVAL;
    }
    
    CFAbsoluteTime wakeTime = CFAbsoluteTimeGetCurrent() + secondsFromNow;
    CFDateRef date = CFDateCreate(kCFAllocatorDefault, wakeTime);
    if (!date) {
        os_log_error(logger, "Failed to create CFDate");
        return -1;
    }
    
    IOPMAssertionID assertionID;
    IOReturn ret = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep,
                                              kIOPMAssertionLevelOn,
                                              CFSTR("PowerEventScheduler"),
                                              &assertionID);
    if (ret != kIOReturnSuccess) {
        os_log_error(logger, "Failed to acquire power management rights: 0x%x", ret);
        CFRelease(date);
        return -1;
    }
    
    ret = IOPMSchedulePowerEvent(date, CFSTR("MyWakeEvent"), CFSTR(kIOPMAutoWakeOrPowerOn));
    IOPMAssertionRelease(assertionID);
    CFRelease(date);
    
    if (ret != kIOReturnSuccess) {
        os_log_error(logger, "Failed to schedule wake event: 0x%x", ret);
        return -1;
    }
    
    os_log_info(logger, "Wake event scheduled successfully");
    return 0;
}

static void handle_event(xpc_connection_t peer, xpc_object_t event) {
    if (!logger) {
        logger = os_log_create("com.flyingthacat.PowerEvent", "Helper");
    }
    
    // Create reply dictionary
    xpc_object_t reply = xpc_dictionary_create_reply(event) ?: xpc_dictionary_create(NULL, NULL, 0);
    
    // Get command
    const char *command = xpc_dictionary_get_string(event, "command");
    int64_t seconds = xpc_dictionary_get_int64(event, "seconds");
    int result = 0;
    const char *message = "Success";
    
    if (command && strcmp(command, "wake") == 0) {
        os_log_info(logger, "Processing wake request for %lld seconds", seconds);
        result = scheduleWakeIOKit((int)seconds);
        message = result == 0 ? "Wake scheduled" : "Failed to schedule wake";
    }
    else if (command && strcmp(command, "sleep") == 0) {
        os_log_info(logger, "Processing sleep request");
        result = scheduleSleepIOKit();
        message = result == 0 ? "Sleep initiated" : "Failed to initiate sleep";
    }
    else {
        os_log_error(logger, "Unknown command received: %lld", seconds ? seconds : 0);
        result = -1;
        message = "Unknown command";
    }
    
    // Format response dictionary - MUST match client's expectations
    xpc_dictionary_set_int64(reply, "result", result);
    xpc_dictionary_set_string(reply, "message", message);
    if (command) {
        xpc_dictionary_set_string(reply, "command", command);
    }
    
    // Send reply
    xpc_connection_send_message(peer, reply);
    
    os_log_info(logger, "Command processed with result: %d", result);
}

static void peer_event_handler(xpc_connection_t peer) {
    xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
        handle_event(peer, event);
    });
    xpc_connection_resume(peer);
}

int main(int argc, const char * argv[]) {
    logger = os_log_create("com.flyingthacat.PowerEvent", "Helper");
    os_log_info(logger, "Privileged helper starting");
    
    xpc_connection_t service = xpc_connection_create_mach_service(
        "com.flyingthacat.PowerEventPrivilegedHelper",
        dispatch_get_main_queue(),
        XPC_CONNECTION_MACH_SERVICE_LISTENER
    );
    
    if (!service) {
        os_log_error(logger, "Failed to create XPC service");
        return EXIT_FAILURE;
    }
    
    xpc_connection_set_event_handler(service, ^(xpc_object_t connection) {
        if (xpc_get_type(connection) == XPC_TYPE_CONNECTION) {
            peer_event_handler(connection);
        }
    });
    
    xpc_connection_resume(service);
    dispatch_main();
    
    return EXIT_SUCCESS;
}
