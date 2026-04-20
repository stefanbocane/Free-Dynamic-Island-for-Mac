import Foundation
import CoreAudio

/// Best-effort check for whether the system default output device is currently running
/// (i.e., audio is being played somewhere). Used by FullscreenWatcher as a heuristic
/// to decide whether a fullscreen app is playing media.
enum AudioActivityService {
    static func isDefaultOutputRunning() -> Bool {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr, 0, nil, &size, &deviceID
        ) == noErr else { return false }

        var isRunning: UInt32 = 0
        var rSize = UInt32(MemoryLayout<UInt32>.size)
        var rAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &rAddr, 0, nil, &rSize, &isRunning)
        return status == noErr && isRunning != 0
    }
}
