#include <CoreAudio/CoreAudio.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static AudioObjectPropertyAddress property(UInt32 selector, UInt32 scope, UInt32 element) {
    return (AudioObjectPropertyAddress){selector, scope, element};
}

static CFStringRef readString(AudioObjectID object, UInt32 selector) {
    CFStringRef value = NULL;
    UInt32 size = sizeof(value);
    AudioObjectPropertyAddress address = property(selector, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain);
    return AudioObjectGetPropertyData(object, &address, 0, NULL, &size, &value) == noErr ? value : NULL;
}

static void printString(CFStringRef value) {
    char text[512] = "";
    if (value && CFStringGetCString(value, text, sizeof(text), kCFStringEncodingUTF8)) printf("%s", text);
}

static Boolean nameContains(AudioObjectID device, const char *needle) {
    CFStringRef name = readString(device, kAudioObjectPropertyName);
    if (!name) return false;
    char text[512] = "";
    Boolean found = CFStringGetCString(name, text, sizeof(text), kCFStringEncodingUTF8) && strstr(text, needle);
    CFRelease(name);
    return found;
}

static void printVolumeProperty(AudioObjectID device, UInt32 selector, const char *label, UInt32 element) {
    AudioObjectPropertyAddress address = property(selector, kAudioDevicePropertyScopeOutput, element);
    if (!AudioObjectHasProperty(device, &address)) return;
    Boolean settable = false;
    AudioObjectIsPropertySettable(device, &address, &settable);
    if (selector == kAudioDevicePropertyVolumeRangeDecibels) {
        AudioValueRange range = {0};
        UInt32 size = sizeof(range);
        if (AudioObjectGetPropertyData(device, &address, 0, NULL, &size, &range) == noErr)
            printf("  element %u %-10s %.2f..%.2f dB settable=%s\n", element, label, range.mMinimum, range.mMaximum, settable ? "yes" : "no");
        return;
    }
    Float32 value = 0;
    UInt32 size = sizeof(value);
    if (AudioObjectGetPropertyData(device, &address, 0, NULL, &size, &value) == noErr)
        printf("  element %u %-10s %.6f settable=%s\n", element, label, value, settable ? "yes" : "no");
}

static void printMute(AudioObjectID device, UInt32 element) {
    AudioObjectPropertyAddress address = property(kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput, element);
    if (!AudioObjectHasProperty(device, &address)) return;
    UInt32 value = 0;
    UInt32 size = sizeof(value);
    Boolean settable = false;
    AudioObjectIsPropertySettable(device, &address, &settable);
    if (AudioObjectGetPropertyData(device, &address, 0, NULL, &size, &value) == noErr)
        printf("  element %u mute       %u settable=%s\n", element, value, settable ? "yes" : "no");
}

static void printDevice(AudioObjectID device) {
    CFStringRef name = readString(device, kAudioObjectPropertyName);
    CFStringRef uid = readString(device, kAudioDevicePropertyDeviceUID);
    printf("device %u name=", device);
    printString(name);
    printf(" uid=");
    printString(uid);
    printf("\n");
    if (name) CFRelease(name);
    if (uid) CFRelease(uid);
    for (UInt32 element = 0; element <= 8; element++) {
        printVolumeProperty(device, kAudioDevicePropertyVolumeScalar, "scalar", element);
        printVolumeProperty(device, kAudioDevicePropertyVolumeDecibels, "decibels", element);
        printVolumeProperty(device, kAudioDevicePropertyVolumeRangeDecibels, "range", element);
        printMute(device, element);
    }
}

static AudioObjectID *readDevices(UInt32 *count) {
    AudioObjectPropertyAddress address = property(kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain);
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &address, 0, NULL, &size) != noErr) return NULL;
    AudioObjectID *devices = malloc(size);
    if (!devices || AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, devices) != noErr) return NULL;
    *count = size / sizeof(*devices);
    return devices;
}

int main(int argc, char **argv) {
    const char *needle = argc > 1 ? argv[1] : "Razer Nommo";
    UInt32 count = 0;
    AudioObjectID *devices = readDevices(&count);
    if (!devices) return 1;
    for (UInt32 index = 0; index < count; index++)
        if (nameContains(devices[index], needle)) printDevice(devices[index]);
    free(devices);
    return 0;
}
