# ==============================================================================
# LogVolume - 対数音量ミキサー (Logarithmic Volume Mixer for Windows)
# ==============================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$csharp = @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Collections.Generic;

namespace LogVolumeApp {
    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceEnumerator {
        [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
        [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
    }

    [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDevice {
        [PreserveSig] int Activate(ref Guid id, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object interfacePointer);
        [PreserveSig] int OpenPropertyStore(int stgmAccess, out IPropertyStore properties);
        [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string strId);
        [PreserveSig] int GetState(out int state);
    }

    [Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore {
        [PreserveSig] int GetCount(out int cProps);
        [PreserveSig] int GetAt(int iProp, out PropertyKey pkey);
        [PreserveSig] int GetValue(ref PropertyKey key, out PropVariant pv);
        [PreserveSig] int SetValue(ref PropertyKey key, ref PropVariant pv);
        [PreserveSig] int Commit();
    }

    public struct PropertyKey {
        public Guid fmtid;
        public int pid;
        public PropertyKey(Guid f, int p) { fmtid = f; pid = p; }
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct PropVariant {
        [FieldOffset(0)] public short vt;
        [FieldOffset(8)] public IntPtr pwszVal;
    }

    [Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioEndpointVolume {
        [PreserveSig] int RegisterControlChangeNotify(IntPtr notify);
        [PreserveSig] int UnregisterControlChangeNotify(IntPtr notify);
        [PreserveSig] int GetChannelCount(out uint channelCount);
        [PreserveSig] int SetMasterVolumeLevel(float levelDB, ref Guid eventContext);
        [PreserveSig] int SetMasterVolumeLevelScalar(float level, ref Guid eventContext);
        [PreserveSig] int GetMasterVolumeLevel(out float levelDB);
        [PreserveSig] int GetMasterVolumeLevelScalar(out float level);
        [PreserveSig] int SetChannelVolumeLevel(uint channelNumber, float levelDB, ref Guid eventContext);
        [PreserveSig] int SetChannelVolumeLevelScalar(uint channelNumber, float level, ref Guid eventContext);
        [PreserveSig] int GetChannelVolumeLevel(uint channelNumber, out float levelDB);
        [PreserveSig] int GetChannelVolumeLevelScalar(uint channelNumber, out float level);
        [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid eventContext);
        [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
        [PreserveSig] int GetVolumeStepInfo(out uint step, out uint stepCount);
        [PreserveSig] int VolumeStepUp(ref Guid eventContext);
        [PreserveSig] int VolumeStepDown(ref Guid eventContext);
        [PreserveSig] int QueryHardwareSupport(out uint hardwareSupportMask);
        [PreserveSig] int GetVolumeRange(out float volumeMinDB, out float volumeMaxDB, out float volumeIncrementDB);
    }

    [Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioSessionManager2 {
        [PreserveSig] int GetAudioSessionControl(ref Guid audioSessionGuid, int streamFlags, out IntPtr sessionControl);
        [PreserveSig] int GetSimpleAudioVolume(ref Guid audioSessionGuid, int streamFlags, out ISimpleAudioVolume audioVolume);
        [PreserveSig] int GetSessionEnumerator(out IAudioSessionEnumerator sessionEnum);
    }

    [Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioSessionEnumerator {
        [PreserveSig] int GetCount(out int sessionCount);
        [PreserveSig] int GetSession(int sessionIndex, out IAudioSessionControl2 session);
    }

    [Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioSessionControl2 {
        [PreserveSig] int GetState(out int state);
        [PreserveSig] int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string displayName);
        [PreserveSig] int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string displayName, ref Guid eventContext);
        [PreserveSig] int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string iconPath);
        [PreserveSig] int SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string iconPath, ref Guid eventContext);
        [PreserveSig] int GetGroupingParam(out Guid groupingParam);
        [PreserveSig] int SetGroupingParam(ref Guid groupingParam, ref Guid eventContext);
        [PreserveSig] int RegisterAudioSessionNotification(IntPtr newNotifications);
        [PreserveSig] int UnregisterAudioSessionNotification(IntPtr newNotifications);
        [PreserveSig] int GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string id);
        [PreserveSig] int GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string id);
        [PreserveSig] int GetProcessId(out int processId);
        [PreserveSig] int IsSystemSoundsSession();
        [PreserveSig] int SetDuckingPreference([MarshalAs(UnmanagedType.Bool)] bool optOut);
    }

    [Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface ISimpleAudioVolume {
        [PreserveSig] int SetMasterVolume(float level, ref Guid eventContext);
        [PreserveSig] int GetMasterVolume(out float level);
        [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid eventContext);
        [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
    }

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    public class MMDeviceEnumeratorComObject { }

    public class AppSessionItem {
        public int ProcessId { get; set; }
        public string DisplayName { get; set; }
        public float VolumeScalar { get; set; }
        public float VolumeDb { get; set; }
        public bool IsMuted { get; set; }
        public override string ToString() { return DisplayName; }
    }

    public static class CoreAudio {
        // --- スピーカー (eRender = 0) ---
        private static IMMDevice GetDefaultRenderEndpoint(out IMMDeviceEnumerator enumerator) {
            enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
            IMMDevice dev = null;
            enumerator.GetDefaultAudioEndpoint(0, 1, out dev);
            return dev;
        }

        // --- マイク (eCapture = 1) ---
        private static IMMDevice GetDefaultCaptureEndpoint(out IMMDeviceEnumerator enumerator) {
            enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
            IMMDevice dev = null;
            // role: 1 (eMultimedia) -> 失敗時 role: 0 (eConsole)
            int hr = enumerator.GetDefaultAudioEndpoint(1, 1, out dev);
            if (hr != 0 || dev == null) {
                enumerator.GetDefaultAudioEndpoint(1, 0, out dev);
            }
            return dev;
        }

        private static string GetDeviceFriendlyName(IMMDevice dev) {
            if (dev == null) return "";
            try {
                IPropertyStore store;
                dev.OpenPropertyStore(0, out store);
                if (store != null) {
                    PropertyKey key = new PropertyKey(new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"), 14);
                    PropVariant pv;
                    store.GetValue(ref key, out pv);
                    string name = Marshal.PtrToStringUni(pv.pwszVal);
                    Marshal.ReleaseComObject(store);
                    return name ?? "";
                }
            } catch {}
            return "";
        }

        // ==========================================
        // マスター音量 (スピーカー / 出力)
        // ==========================================
        public static float GetMasterDb() {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioEndpointVolume epv = null;
            try {
                dev = GetDefaultRenderEndpoint(out enumerator);
                if (dev == null) return 0f;
                Guid IID = typeof(IAudioEndpointVolume).GUID;
                object obj;
                dev.Activate(ref IID, 1, IntPtr.Zero, out obj);
                epv = obj as IAudioEndpointVolume;
                if (epv != null) {
                    float db;
                    epv.GetMasterVolumeLevel(out db);
                    return db;
                }
                return 0f;
            } catch { return 0f; }
            finally {
                if (epv != null) Marshal.ReleaseComObject(epv);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static float GetMasterScalar() {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioEndpointVolume epv = null;
            try {
                dev = GetDefaultRenderEndpoint(out enumerator);
                if (dev == null) return 1f;
                Guid IID = typeof(IAudioEndpointVolume).GUID;
                object obj;
                dev.Activate(ref IID, 1, IntPtr.Zero, out obj);
                epv = obj as IAudioEndpointVolume;
                if (epv != null) {
                    float scalar;
                    epv.GetMasterVolumeLevelScalar(out scalar);
                    return scalar;
                }
                return 1f;
            } catch { return 1f; }
            finally {
                if (epv != null) Marshal.ReleaseComObject(epv);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static void SetMasterDb(float db) {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioEndpointVolume epv = null;
            try {
                dev = GetDefaultRenderEndpoint(out enumerator);
                if (dev == null) return;
                Guid IID = typeof(IAudioEndpointVolume).GUID;
                object obj;
                dev.Activate(ref IID, 1, IntPtr.Zero, out obj);
                epv = obj as IAudioEndpointVolume;
                if (epv != null) {
                    float minDb, maxDb, incDb;
                    epv.GetVolumeRange(out minDb, out maxDb, out incDb);
                    if (db < minDb) db = minDb;
                    if (db > maxDb) db = maxDb;
                    Guid empty = Guid.Empty;
                    epv.SetMasterVolumeLevel(db, ref empty);
                }
            } catch {}
            finally {
                if (epv != null) Marshal.ReleaseComObject(epv);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static bool GetMasterMute() {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioEndpointVolume epv = null;
            try {
                dev = GetDefaultRenderEndpoint(out enumerator);
                if (dev == null) return false;
                Guid IID = typeof(IAudioEndpointVolume).GUID;
                object obj;
                dev.Activate(ref IID, 1, IntPtr.Zero, out obj);
                epv = obj as IAudioEndpointVolume;
                if (epv != null) {
                    bool mute;
                    epv.GetMute(out mute);
                    return mute;
                }
                return false;
            } catch { return false; }
            finally {
                if (epv != null) Marshal.ReleaseComObject(epv);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static void SetMasterMute(bool mute) {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioEndpointVolume epv = null;
            try {
                dev = GetDefaultRenderEndpoint(out enumerator);
                if (dev == null) return;
                Guid IID = typeof(IAudioEndpointVolume).GUID;
                object obj;
                dev.Activate(ref IID, 1, IntPtr.Zero, out obj);
                epv = obj as IAudioEndpointVolume;
                if (epv != null) {
                    Guid empty = Guid.Empty;
                    epv.SetMute(mute, ref empty);
                }
            } catch {}
            finally {
                if (epv != null) Marshal.ReleaseComObject(epv);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        // ==========================================
        // マイク音量 (入力 / キャプチャ)
        // ==========================================
        public static bool IsMicAvailable() {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            try {
                dev = GetDefaultCaptureEndpoint(out enumerator);
                return dev != null;
            } catch { return false; }
            finally {
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static string GetMicDeviceName() {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            try {
                dev = GetDefaultCaptureEndpoint(out enumerator);
                if (dev == null) return "未接続";
                string name = GetDeviceFriendlyName(dev);
                return string.IsNullOrEmpty(name) ? "既定のマイク" : name;
            } catch { return "未接続"; }
            finally {
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static float GetMicScalar() {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioEndpointVolume epv = null;
            try {
                dev = GetDefaultCaptureEndpoint(out enumerator);
                if (dev == null) return 0f;
                Guid IID = typeof(IAudioEndpointVolume).GUID;
                object obj;
                dev.Activate(ref IID, 1, IntPtr.Zero, out obj);
                epv = obj as IAudioEndpointVolume;
                if (epv != null) {
                    float scalar;
                    epv.GetMasterVolumeLevelScalar(out scalar);
                    return scalar;
                }
                return 0f;
            } catch { return 0f; }
            finally {
                if (epv != null) Marshal.ReleaseComObject(epv);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static void SetMicScalar(float scalar) {
            if (scalar < 0f) scalar = 0f;
            if (scalar > 1f) scalar = 1f;
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioEndpointVolume epv = null;
            try {
                dev = GetDefaultCaptureEndpoint(out enumerator);
                if (dev == null) return;
                Guid IID = typeof(IAudioEndpointVolume).GUID;
                object obj;
                dev.Activate(ref IID, 1, IntPtr.Zero, out obj);
                epv = obj as IAudioEndpointVolume;
                if (epv != null) {
                    Guid empty = Guid.Empty;
                    epv.SetMasterVolumeLevelScalar(scalar, ref empty);
                }
            } catch {}
            finally {
                if (epv != null) Marshal.ReleaseComObject(epv);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static float GetMicDb() {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioEndpointVolume epv = null;
            try {
                dev = GetDefaultCaptureEndpoint(out enumerator);
                if (dev == null) return 0f;
                Guid IID = typeof(IAudioEndpointVolume).GUID;
                object obj;
                dev.Activate(ref IID, 1, IntPtr.Zero, out obj);
                epv = obj as IAudioEndpointVolume;
                if (epv != null) {
                    float db;
                    epv.GetMasterVolumeLevel(out db);
                    return db;
                }
                return 0f;
            } catch { return 0f; }
            finally {
                if (epv != null) Marshal.ReleaseComObject(epv);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static bool GetMicMute() {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioEndpointVolume epv = null;
            try {
                dev = GetDefaultCaptureEndpoint(out enumerator);
                if (dev == null) return false;
                Guid IID = typeof(IAudioEndpointVolume).GUID;
                object obj;
                dev.Activate(ref IID, 1, IntPtr.Zero, out obj);
                epv = obj as IAudioEndpointVolume;
                if (epv != null) {
                    bool mute;
                    epv.GetMute(out mute);
                    return mute;
                }
                return false;
            } catch { return false; }
            finally {
                if (epv != null) Marshal.ReleaseComObject(epv);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static void SetMicMute(bool mute) {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioEndpointVolume epv = null;
            try {
                dev = GetDefaultCaptureEndpoint(out enumerator);
                if (dev == null) return;
                Guid IID = typeof(IAudioEndpointVolume).GUID;
                object obj;
                dev.Activate(ref IID, 1, IntPtr.Zero, out obj);
                epv = obj as IAudioEndpointVolume;
                if (epv != null) {
                    Guid empty = Guid.Empty;
                    epv.SetMute(mute, ref empty);
                }
            } catch {}
            finally {
                if (epv != null) Marshal.ReleaseComObject(epv);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        // ==========================================
        // アプリケーション音量セッション
        // ==========================================
        public static List<AppSessionItem> GetSessions() {
            var list = new List<AppSessionItem>();
            var seenPids = new HashSet<int>();
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioSessionManager2 mgr = null;
            IAudioSessionEnumerator sessionEnum = null;
            try {
                dev = GetDefaultRenderEndpoint(out enumerator);
                if (dev == null) return list;
                Guid IID_Mgr = typeof(IAudioSessionManager2).GUID;
                object obj;
                dev.Activate(ref IID_Mgr, 1, IntPtr.Zero, out obj);
                mgr = obj as IAudioSessionManager2;
                if (mgr == null) return list;

                mgr.GetSessionEnumerator(out sessionEnum);
                if (sessionEnum == null) return list;

                int count;
                sessionEnum.GetCount(out count);

                for (int i = 0; i < count; i++) {
                    IAudioSessionControl2 ctl = null;
                    try {
                        sessionEnum.GetSession(i, out ctl);
                        if (ctl == null) continue;

                        int pid = 0;
                        ctl.GetProcessId(out pid);
                        int isSys = ctl.IsSystemSoundsSession();

                        if (seenPids.Contains(pid)) continue;

                        string friendlyName = "";
                        if (isSys == 0 || pid == 0) {
                            friendlyName = "システム音 (System Sounds)";
                        } else {
                            try {
                                var proc = Process.GetProcessById(pid);
                                if (!string.IsNullOrEmpty(proc.MainWindowTitle)) {
                                    friendlyName = string.Format("{0} ({1})", proc.MainWindowTitle, proc.ProcessName);
                                } else {
                                    friendlyName = proc.ProcessName;
                                }
                            } catch {
                                friendlyName = "プロセス " + pid;
                            }
                        }

                        var sv = ctl as ISimpleAudioVolume;
                        float vol = 1.0f;
                        bool mute = false;
                        if (sv != null) {
                            sv.GetMasterVolume(out vol);
                            sv.GetMute(out mute);
                        }

                        float db = vol > 0.00001f ? (float)(20.0 * Math.Log10(vol)) : -60.0f;
                        if (db < -60.0f) db = -60.0f;

                        seenPids.Add(pid);
                        list.Add(new AppSessionItem {
                            ProcessId = pid,
                            DisplayName = pid > 0 ? string.Format("{0} [PID: {1}]", friendlyName, pid) : friendlyName,
                            VolumeScalar = vol,
                            VolumeDb = db,
                            IsMuted = mute
                        });
                    } finally {
                        if (ctl != null) Marshal.ReleaseComObject(ctl);
                    }
                }
            } catch {}
            finally {
                if (sessionEnum != null) Marshal.ReleaseComObject(sessionEnum);
                if (mgr != null) Marshal.ReleaseComObject(mgr);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
            return list;
        }

        public static float GetSessionDb(int targetPid) {
            float vol = GetSessionScalar(targetPid);
            float db = vol > 0.00001f ? (float)(20.0 * Math.Log10(vol)) : -60.0f;
            if (db < -60.0f) db = -60.0f;
            return db;
        }

        public static float GetSessionScalar(int targetPid) {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioSessionManager2 mgr = null;
            IAudioSessionEnumerator sessionEnum = null;
            try {
                dev = GetDefaultRenderEndpoint(out enumerator);
                if (dev == null) return 1.0f;
                Guid IID_Mgr = typeof(IAudioSessionManager2).GUID;
                object obj;
                dev.Activate(ref IID_Mgr, 1, IntPtr.Zero, out obj);
                mgr = obj as IAudioSessionManager2;
                if (mgr == null) return 1.0f;

                mgr.GetSessionEnumerator(out sessionEnum);
                if (sessionEnum == null) return 1.0f;

                int count;
                sessionEnum.GetCount(out count);

                for (int i = 0; i < count; i++) {
                    IAudioSessionControl2 ctl = null;
                    try {
                        sessionEnum.GetSession(i, out ctl);
                        if (ctl == null) continue;

                        int pid = 0;
                        ctl.GetProcessId(out pid);

                        if (targetPid == -1 || pid == targetPid) {
                            var sv = ctl as ISimpleAudioVolume;
                            if (sv != null) {
                                float vol;
                                sv.GetMasterVolume(out vol);
                                return vol;
                            }
                        }
                    } finally {
                        if (ctl != null) Marshal.ReleaseComObject(ctl);
                    }
                }
                return 1.0f;
            } catch { return 1.0f; }
            finally {
                if (sessionEnum != null) Marshal.ReleaseComObject(sessionEnum);
                if (mgr != null) Marshal.ReleaseComObject(mgr);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static void SetSessionDb(int pid, float db) {
            if (db < -60.0f) {
                SetSessionScalar(pid, 0.0f);
            } else {
                float scalar = (float)Math.Pow(10.0, db / 20.0);
                if (scalar > 1.0f) scalar = 1.0f;
                SetSessionScalar(pid, scalar);
            }
        }

        public static void SetSessionScalar(int targetPid, float scalar) {
            if (scalar < 0f) scalar = 0f;
            if (scalar > 1f) scalar = 1f;

            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioSessionManager2 mgr = null;
            IAudioSessionEnumerator sessionEnum = null;
            try {
                dev = GetDefaultRenderEndpoint(out enumerator);
                if (dev == null) return;
                Guid IID_Mgr = typeof(IAudioSessionManager2).GUID;
                object obj;
                dev.Activate(ref IID_Mgr, 1, IntPtr.Zero, out obj);
                mgr = obj as IAudioSessionManager2;
                if (mgr == null) return;

                mgr.GetSessionEnumerator(out sessionEnum);
                if (sessionEnum == null) return;

                int count;
                sessionEnum.GetCount(out count);
                Guid empty = Guid.Empty;

                for (int i = 0; i < count; i++) {
                    IAudioSessionControl2 ctl = null;
                    try {
                        sessionEnum.GetSession(i, out ctl);
                        if (ctl == null) continue;

                        int pid = 0;
                        ctl.GetProcessId(out pid);

                        if (targetPid == -1 || pid == targetPid) {
                            var sv = ctl as ISimpleAudioVolume;
                            if (sv != null) {
                                sv.SetMasterVolume(scalar, ref empty);
                            }
                        }
                    } finally {
                        if (ctl != null) Marshal.ReleaseComObject(ctl);
                    }
                }
            } catch {}
            finally {
                if (sessionEnum != null) Marshal.ReleaseComObject(sessionEnum);
                if (mgr != null) Marshal.ReleaseComObject(mgr);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static void SetSessionMute(int targetPid, bool mute) {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioSessionManager2 mgr = null;
            IAudioSessionEnumerator sessionEnum = null;
            try {
                dev = GetDefaultRenderEndpoint(out enumerator);
                if (dev == null) return;
                Guid IID_Mgr = typeof(IAudioSessionManager2).GUID;
                object obj;
                dev.Activate(ref IID_Mgr, 1, IntPtr.Zero, out obj);
                mgr = obj as IAudioSessionManager2;
                if (mgr == null) return;

                mgr.GetSessionEnumerator(out sessionEnum);
                if (sessionEnum == null) return;

                int count;
                sessionEnum.GetCount(out count);
                Guid empty = Guid.Empty;

                for (int i = 0; i < count; i++) {
                    IAudioSessionControl2 ctl = null;
                    try {
                        sessionEnum.GetSession(i, out ctl);
                        if (ctl == null) continue;

                        int pid = 0;
                        ctl.GetProcessId(out pid);

                        if (targetPid == -1 || pid == targetPid) {
                            var sv = ctl as ISimpleAudioVolume;
                            if (sv != null) {
                                sv.SetMute(mute, ref empty);
                            }
                        }
                    } finally {
                        if (ctl != null) Marshal.ReleaseComObject(ctl);
                    }
                }
            } catch {}
            finally {
                if (sessionEnum != null) Marshal.ReleaseComObject(sessionEnum);
                if (mgr != null) Marshal.ReleaseComObject(mgr);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static bool GetSessionMute(int targetPid) {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioSessionManager2 mgr = null;
            IAudioSessionEnumerator sessionEnum = null;
            try {
                dev = GetDefaultRenderEndpoint(out enumerator);
                if (dev == null) return false;
                Guid IID_Mgr = typeof(IAudioSessionManager2).GUID;
                object obj;
                dev.Activate(ref IID_Mgr, 1, IntPtr.Zero, out obj);
                mgr = obj as IAudioSessionManager2;
                if (mgr == null) return false;

                mgr.GetSessionEnumerator(out sessionEnum);
                if (sessionEnum == null) return false;

                int count;
                sessionEnum.GetCount(out count);

                for (int i = 0; i < count; i++) {
                    IAudioSessionControl2 ctl = null;
                    try {
                        sessionEnum.GetSession(i, out ctl);
                        if (ctl == null) continue;

                        int pid = 0;
                        ctl.GetProcessId(out pid);

                        if (targetPid == -1 || pid == targetPid) {
                            var sv = ctl as ISimpleAudioVolume;
                            if (sv != null) {
                                bool mute;
                                sv.GetMute(out mute);
                                return mute;
                            }
                        }
                    } finally {
                        if (ctl != null) Marshal.ReleaseComObject(ctl);
                    }
                }
                return false;
            } catch { return false; }
            finally {
                if (sessionEnum != null) Marshal.ReleaseComObject(sessionEnum);
                if (mgr != null) Marshal.ReleaseComObject(mgr);
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }
    }
}
"@

Add-Type -TypeDefinition $csharp

# --- GUI構築 ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "LogVolume - 対数音量ミキサー"
$form.Size = New-Object System.Drawing.Size(515, 785)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 30)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Meiryo UI", 9)
$form.TopMost = $true

# 最前面トグル
$chkTopMost = New-Object System.Windows.Forms.CheckBox
$chkTopMost.Text = "常に最前面に表示"
$chkTopMost.Checked = $true
$chkTopMost.Location = New-Object System.Drawing.Point(20, 12)
$chkTopMost.AutoSize = $true
$chkTopMost.Add_CheckedChanged({ $form.TopMost = $chkTopMost.Checked })
$form.Controls.Add($chkTopMost)

# --- 1. マスター音量グループ (スピーカー / 出力) ---
$grpMaster = New-Object System.Windows.Forms.GroupBox
$grpMaster.Text = " 1. マスター音量 (全体 / 出力) "
$grpMaster.Location = New-Object System.Drawing.Point(15, 38)
$grpMaster.Size = New-Object System.Drawing.Size(470, 185)
$grpMaster.ForeColor = [System.Drawing.Color]::FromArgb(180, 210, 255)

$lblMasterVal = New-Object System.Windows.Forms.Label
$lblMasterVal.Location = New-Object System.Drawing.Point(15, 25)
$lblMasterVal.Size = New-Object System.Drawing.Size(320, 26)
$lblMasterVal.Font = New-Object System.Drawing.Font("Meiryo UI", 10, [System.Drawing.FontStyle]::Bold)
$lblMasterVal.ForeColor = [System.Drawing.Color]::White
$grpMaster.Controls.Add($lblMasterVal)

$btnMasterMute = New-Object System.Windows.Forms.Button
$btnMasterMute.Location = New-Object System.Drawing.Point(345, 20)
$btnMasterMute.Size = New-Object System.Drawing.Size(110, 32)
$btnMasterMute.FlatStyle = "Flat"
$btnMasterMute.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 60)
$btnMasterMute.ForeColor = [System.Drawing.Color]::White
$grpMaster.Controls.Add($btnMasterMute)

$trackMaster = New-Object System.Windows.Forms.TrackBar
$trackMaster.Location = New-Object System.Drawing.Point(10, 58)
$trackMaster.Size = New-Object System.Drawing.Size(450, 45)
$trackMaster.Minimum = -120 # -60 dB (0.5 dB刻み)
$trackMaster.Maximum = 0    # 0 dB
$trackMaster.TickFrequency = 10
$grpMaster.Controls.Add($trackMaster)

# マスタープリセット
$pnlMasterPresets = New-Object System.Windows.Forms.Panel
$pnlMasterPresets.Location = New-Object System.Drawing.Point(10, 115)
$pnlMasterPresets.Size = New-Object System.Drawing.Size(450, 55)

$masterPresets = @(
    @{ Text = "-40 dB (1%)";   Db = -40.0 },
    @{ Text = "-30 dB (3%)";   Db = -30.0 },
    @{ Text = "-20 dB (10%)";  Db = -20.0 },
    @{ Text = "-10 dB (32%)";  Db = -10.0 },
    @{ Text = "0 dB (100%)";   Db = 0.0 }
)
$mx = 0
foreach ($p in $masterPresets) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $p.Text
    $btn.Size = New-Object System.Drawing.Size(86, 34)
    $btn.Location = New-Object System.Drawing.Point($mx, 5)
    $btn.FlatStyle = "Flat"
    $btn.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 50)
    $btn.ForeColor = [System.Drawing.Color]::FromArgb(210, 220, 235)
    $targetDb = $p.Db
    $btn.Add_Click({
        [LogVolumeApp.CoreAudio]::SetMasterDb($targetDb)
        UpdateMasterUI
    }.GetNewClosure())
    $pnlMasterPresets.Controls.Add($btn)
    $mx += 90
}
$grpMaster.Controls.Add($pnlMasterPresets)
$form.Controls.Add($grpMaster)

# --- 2. マイク音量グループ (入力) ---
$grpMic = New-Object System.Windows.Forms.GroupBox
$grpMic.Text = " 2. マイク音量 (入力) "
$grpMic.Location = New-Object System.Drawing.Point(15, 232)
$grpMic.Size = New-Object System.Drawing.Size(470, 190)
$grpMic.ForeColor = [System.Drawing.Color]::FromArgb(255, 210, 160)

$lblMicName = New-Object System.Windows.Forms.Label
$lblMicName.Location = New-Object System.Drawing.Point(15, 22)
$lblMicName.Size = New-Object System.Drawing.Size(320, 18)
$lblMicName.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$lblMicName.Font = New-Object System.Drawing.Font("Meiryo UI", 8.25)
$grpMic.Controls.Add($lblMicName)

$lblMicVal = New-Object System.Windows.Forms.Label
$lblMicVal.Location = New-Object System.Drawing.Point(15, 42)
$lblMicVal.Size = New-Object System.Drawing.Size(320, 26)
$lblMicVal.Font = New-Object System.Drawing.Font("Meiryo UI", 10, [System.Drawing.FontStyle]::Bold)
$lblMicVal.ForeColor = [System.Drawing.Color]::White
$grpMic.Controls.Add($lblMicVal)

$btnMicMute = New-Object System.Windows.Forms.Button
$btnMicMute.Location = New-Object System.Drawing.Point(345, 28)
$btnMicMute.Size = New-Object System.Drawing.Size(110, 32)
$btnMicMute.FlatStyle = "Flat"
$btnMicMute.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 60)
$btnMicMute.ForeColor = [System.Drawing.Color]::White
$grpMic.Controls.Add($btnMicMute)

$trackMic = New-Object System.Windows.Forms.TrackBar
$trackMic.Location = New-Object System.Drawing.Point(10, 72)
$trackMic.Size = New-Object System.Drawing.Size(450, 45)
$trackMic.Minimum = 0   # 0 %
$trackMic.Maximum = 100 # 100 %
$trackMic.TickFrequency = 10
$grpMic.Controls.Add($trackMic)

# マイクプリセット
$pnlMicPresets = New-Object System.Windows.Forms.Panel
$pnlMicPresets.Location = New-Object System.Drawing.Point(10, 126)
$pnlMicPresets.Size = New-Object System.Drawing.Size(450, 55)

$micPresets = @(
    @{ Text = "0% (消音)"; Scalar = 0.00 },
    @{ Text = "25%";       Scalar = 0.25 },
    @{ Text = "50%";       Scalar = 0.50 },
    @{ Text = "75%";       Scalar = 0.75 },
    @{ Text = "100%";      Scalar = 1.00 }
)
$ux = 0
foreach ($p in $micPresets) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $p.Text
    $btn.Size = New-Object System.Drawing.Size(86, 34)
    $btn.Location = New-Object System.Drawing.Point($ux, 5)
    $btn.FlatStyle = "Flat"
    $btn.BackColor = [System.Drawing.Color]::FromArgb(50, 45, 40)
    $btn.ForeColor = [System.Drawing.Color]::FromArgb(240, 220, 200)
    $targetScalar = $p.Scalar
    $btn.Add_Click({
        [LogVolumeApp.CoreAudio]::SetMicScalar($targetScalar)
        UpdateMicUI
    }.GetNewClosure())
    $pnlMicPresets.Controls.Add($btn)
    $ux += 90
}
$grpMic.Controls.Add($pnlMicPresets)
$form.Controls.Add($grpMic)

# --- 3. アプリケーション音量グループ ---
$grpApp = New-Object System.Windows.Forms.GroupBox
$grpApp.Text = " 3. アプリケーション音量 (対数・微小調整) "
$grpApp.Location = New-Object System.Drawing.Point(15, 430)
$grpApp.Size = New-Object System.Drawing.Size(470, 310)
$grpApp.ForeColor = [System.Drawing.Color]::FromArgb(180, 255, 210)

$lblAppSelect = New-Object System.Windows.Forms.Label
$lblAppSelect.Text = "対象アプリ:"
$lblAppSelect.Location = New-Object System.Drawing.Point(15, 26)
$lblAppSelect.Size = New-Object System.Drawing.Size(75, 20)
$grpApp.Controls.Add($lblAppSelect)

$cmbApps = New-Object System.Windows.Forms.ComboBox
$cmbApps.Location = New-Object System.Drawing.Point(90, 22)
$cmbApps.Size = New-Object System.Drawing.Size(235, 26)
$cmbApps.DropDownStyle = "DropDownList"
$cmbApps.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$cmbApps.ForeColor = [System.Drawing.Color]::White
$grpApp.Controls.Add($cmbApps)

$btnAppMute = New-Object System.Windows.Forms.Button
$btnAppMute.Text = "消音"
$btnAppMute.Location = New-Object System.Drawing.Point(332, 20)
$btnAppMute.Size = New-Object System.Drawing.Size(64, 28)
$btnAppMute.FlatStyle = "Flat"
$btnAppMute.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 60)
$btnAppMute.ForeColor = [System.Drawing.Color]::White
$grpApp.Controls.Add($btnAppMute)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "更新"
$btnRefresh.Location = New-Object System.Drawing.Point(401, 20)
$btnRefresh.Size = New-Object System.Drawing.Size(54, 28)
$btnRefresh.FlatStyle = "Flat"
$btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 60)
$btnRefresh.ForeColor = [System.Drawing.Color]::White
$grpApp.Controls.Add($btnRefresh)

$lblAppVal = New-Object System.Windows.Forms.Label
$lblAppVal.Location = New-Object System.Drawing.Point(15, 62)
$lblAppVal.Size = New-Object System.Drawing.Size(440, 24)
$lblAppVal.Font = New-Object System.Drawing.Font("Meiryo UI", 10, [System.Drawing.FontStyle]::Bold)
$lblAppVal.ForeColor = [System.Drawing.Color]::White
$grpApp.Controls.Add($lblAppVal)

$trackApp = New-Object System.Windows.Forms.TrackBar
$trackApp.Location = New-Object System.Drawing.Point(10, 92)
$trackApp.Size = New-Object System.Drawing.Size(450, 45)
$trackApp.Minimum = -120 # -60 dB (0.5 dB刻み)
$trackApp.Maximum = 0    # 0 dB
$trackApp.TickFrequency = 10
$grpApp.Controls.Add($trackApp)

# アプリ微小音量プリセット
$lblPresetHint = New-Object System.Windows.Forms.Label
$lblPresetHint.Text = "★ 微小音量プリセット (Windows標準の1%以下の世界):"
$lblPresetHint.Location = New-Object System.Drawing.Point(15, 145)
$lblPresetHint.Size = New-Object System.Drawing.Size(440, 22)
$lblPresetHint.ForeColor = [System.Drawing.Color]::FromArgb(255, 220, 120)
$grpApp.Controls.Add($lblPresetHint)

$pnlAppPresets = New-Object System.Windows.Forms.Panel
$pnlAppPresets.Location = New-Object System.Drawing.Point(10, 170)
$pnlAppPresets.Size = New-Object System.Drawing.Size(450, 50)

$appPresets = @(
    @{ Text = "-60dB (0.1%)";  Db = -60.0 },
    @{ Text = "-52dB (0.25%)"; Db = -52.0 },
    @{ Text = "-46dB (0.5%)";  Db = -46.0 },
    @{ Text = "-40dB (1%)";    Db = -40.0 },
    @{ Text = "-34dB (2%)";    Db = -34.0 }
)
$ax = 0
foreach ($p in $appPresets) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $p.Text
    $btn.Size = New-Object System.Drawing.Size(86, 38)
    $btn.Location = New-Object System.Drawing.Point($ax, 5)
    $btn.FlatStyle = "Flat"
    $btn.BackColor = [System.Drawing.Color]::FromArgb(35, 50, 40)
    $btn.ForeColor = [System.Drawing.Color]::FromArgb(180, 255, 200)
    $targetDb = $p.Db
    $btn.Add_Click({
        $trackApp.Value = [int]($targetDb * 2)
        ApplyAppVolumeFromTrackbar
    }.GetNewClosure())
    $pnlAppPresets.Controls.Add($btn)
    $ax += 90
}
$grpApp.Controls.Add($pnlAppPresets)

$lblNote = New-Object System.Windows.Forms.Label
$lblNote.Text = "※「全アプリ一括適用」を選択した場合、操作した瞬間に全セッションへ反映されます。"
$lblNote.Location = New-Object System.Drawing.Point(15, 230)
$lblNote.Size = New-Object System.Drawing.Size(440, 35)
$lblNote.ForeColor = [System.Drawing.Color]::FromArgb(150, 160, 150)
$lblNote.Font = New-Object System.Drawing.Font("Meiryo UI", 8.25)
$grpApp.Controls.Add($lblNote)

$form.Controls.Add($grpApp)

# --- UI更新ロジック ---
function UpdateMasterUI {
    $db = [LogVolumeApp.CoreAudio]::GetMasterDb()
    $scalar = [LogVolumeApp.CoreAudio]::GetMasterScalar()
    $pct = [math]::Round($scalar * 100, 1)
    $lblMasterVal.Text = "マスター音量: $([math]::Round($db, 1)) dB ($pct %)"

    $val = [int]($db * 2)
    if ($val -lt -120) { $val = -120 }
    if ($val -gt 0) { $val = 0 }
    if ($trackMaster.Value -ne $val) {
        $trackMaster.Value = $val
    }

    $mute = [LogVolumeApp.CoreAudio]::GetMasterMute()
    $btnMasterMute.Text = if ($mute) { "ミュート中" } else { "消音" }
    $btnMasterMute.BackColor = if ($mute) { [System.Drawing.Color]::FromArgb(160, 45, 45) } else { [System.Drawing.Color]::FromArgb(55, 55, 60) }
}

function UpdateMicUI {
    if (-not [LogVolumeApp.CoreAudio]::IsMicAvailable()) {
        $lblMicName.Text = "デバイス: 未検出"
        $lblMicVal.Text = "マイクが接続されていません"
        $btnMicMute.Enabled = $false
        $trackMic.Enabled = $false
        $pnlMicPresets.Enabled = $false
        return
    }

    $btnMicMute.Enabled = $true
    $trackMic.Enabled = $true
    $pnlMicPresets.Enabled = $true

    $micName = [LogVolumeApp.CoreAudio]::GetMicDeviceName()
    $lblMicName.Text = "デバイス: $micName"

    $scalar = [LogVolumeApp.CoreAudio]::GetMicScalar()
    $db = [LogVolumeApp.CoreAudio]::GetMicDb()
    $pct = [int][math]::Round($scalar * 100)
    $dbSign = if ($db -ge 0) { "+$([math]::Round($db, 1))" } else { "$([math]::Round($db, 1))" }
    $lblMicVal.Text = "マイク音量: $pct % ($dbSign dB)"

    if ($trackMic.Value -ne $pct) {
        $trackMic.Value = $pct
    }

    $mute = [LogVolumeApp.CoreAudio]::GetMicMute()
    $btnMicMute.Text = if ($mute) { "消音中" } else { "消音" }
    $btnMicMute.BackColor = if ($mute) { [System.Drawing.Color]::FromArgb(160, 45, 45) } else { [System.Drawing.Color]::FromArgb(55, 55, 60) }
}

function UpdateAppMuteButton($mute) {
    $btnAppMute.Text = if ($mute) { "消音中" } else { "消音" }
    $btnAppMute.BackColor = if ($mute) { [System.Drawing.Color]::FromArgb(160, 45, 45) } else { [System.Drawing.Color]::FromArgb(55, 55, 60) }
}

function RefreshAppList {
    $currentSelectedPid = -999
    if ($cmbApps.SelectedItem -ne $null) {
        $currentSelectedPid = $cmbApps.SelectedItem.ProcessId
    }

    $cmbApps.BeginUpdate()
    $cmbApps.Items.Clear()

    # 全アプリ一括項目
    $allItem = New-Object LogVolumeApp.AppSessionItem
    $allItem.ProcessId = -1
    $allItem.DisplayName = "[★ 全アプリ一括適用 (All Apps)]"
    $allItem.VolumeScalar = 1.0
    $allItem.VolumeDb = 0.0
    [void]$cmbApps.Items.Add($allItem)

    $sessions = [LogVolumeApp.CoreAudio]::GetSessions()
    $selectedIdx = -1
    $i = 1
    foreach ($s in $sessions) {
        [void]$cmbApps.Items.Add($s)
        if ($s.ProcessId -eq $currentSelectedPid) {
            $selectedIdx = $i
        }
        $i++
    }
    $cmbApps.EndUpdate()

    # 選択項目の復元または初期選択
    if ($selectedIdx -ge 0) {
        $cmbApps.SelectedIndex = $selectedIdx
    } elseif ($cmbApps.Items.Count -gt 1) {
        # 実アプリが存在する場合は最初の実アプリ (index 1) を選択
        $cmbApps.SelectedIndex = 1
    } else {
        $cmbApps.SelectedIndex = 0
    }

    UpdateAppUIFromSelection
}

function UpdateAppUIFromSelection {
    $sel = $cmbApps.SelectedItem
    if ($sel -eq $null) { return }

    if ($sel.ProcessId -eq -1) {
        # 全アプリ一括: 現在のトラックバー値に基づく表示のみ
        $db = $trackApp.Value / 2.0
        $scalar = [math]::Pow(10.0, $db / 20.0)
        $pct = [math]::Round($scalar * 100, 2)
        $lblAppVal.Text = "一括適用音量: $([math]::Round($db, 1)) dB ($pct %)"
        UpdateAppMuteButton $false
    } else {
        # 個別アプリ: 最新の音量を取得してトラックバーにロード
        $db = [LogVolumeApp.CoreAudio]::GetSessionDb($sel.ProcessId)
        $scalar = [LogVolumeApp.CoreAudio]::GetSessionScalar($sel.ProcessId)
        $mute = [LogVolumeApp.CoreAudio]::GetSessionMute($sel.ProcessId)

        $val = [int]($db * 2)
        if ($val -lt -120) { $val = -120 }
        if ($val -gt 0) { $val = 0 }
        $trackApp.Value = $val

        $pct = [math]::Round($scalar * 100, 2)
        $lblAppVal.Text = "音量: $([math]::Round($db, 1)) dB ($pct %)"
        UpdateAppMuteButton $mute
    }
}

function ApplyAppVolumeFromTrackbar {
    $db = $trackApp.Value / 2.0
    $scalar = [math]::Pow(10.0, $db / 20.0)
    $pct = [math]::Round($scalar * 100, 2)

    $sel = $cmbApps.SelectedItem
    if ($sel -ne $null) {
        $targetPid = $sel.ProcessId
        [LogVolumeApp.CoreAudio]::SetSessionDb($targetPid, $db)
        if ($targetPid -eq -1) {
            $lblAppVal.Text = "一括適用音量: $([math]::Round($db, 1)) dB ($pct %)"
        } else {
            $lblAppVal.Text = "音量: $([math]::Round($db, 1)) dB ($pct %)"
        }
    }
}

# --- イベントハンドラ登録 ---
$trackMaster.Add_Scroll({
    $db = $trackMaster.Value / 2.0
    [LogVolumeApp.CoreAudio]::SetMasterDb($db)
    $scalar = [LogVolumeApp.CoreAudio]::GetMasterScalar()
    $pct = [math]::Round($scalar * 100, 1)
    $lblMasterVal.Text = "マスター音量: $([math]::Round($db, 1)) dB ($pct %)"
})

$btnMasterMute.Add_Click({
    $mute = [LogVolumeApp.CoreAudio]::GetMasterMute()
    [LogVolumeApp.CoreAudio]::SetMasterMute(-not $mute)
    UpdateMasterUI
})

$trackMic.Add_Scroll({
    $scalar = $trackMic.Value / 100.0
    [LogVolumeApp.CoreAudio]::SetMicScalar($scalar)
    $db = [LogVolumeApp.CoreAudio]::GetMicDb()
    $dbSign = if ($db -ge 0) { "+$([math]::Round($db, 1))" } else { "$([math]::Round($db, 1))" }
    $lblMicVal.Text = "マイク音量: $($trackMic.Value) % ($dbSign dB)"
})

$btnMicMute.Add_Click({
    $mute = [LogVolumeApp.CoreAudio]::GetMicMute()
    [LogVolumeApp.CoreAudio]::SetMicMute(-not $mute)
    UpdateMicUI
})

$trackApp.Add_Scroll({
    ApplyAppVolumeFromTrackbar
})

$btnAppMute.Add_Click({
    $sel = $cmbApps.SelectedItem
    if ($sel -ne $null) {
        $targetPid = $sel.ProcessId
        $curMute = [LogVolumeApp.CoreAudio]::GetSessionMute($targetPid)
        [LogVolumeApp.CoreAudio]::SetSessionMute($targetPid, -not $curMute)
        UpdateAppMuteButton (-not $curMute)
    }
})

$btnRefresh.Add_Click({
    RefreshAppList
})

$cmbApps.Add_SelectedIndexChanged({
    UpdateAppUIFromSelection
})

# --- バックグラウンド同期タイマー ---
$timerSync = New-Object System.Windows.Forms.Timer
$timerSync.Interval = 1000
$timerSync.Add_Tick({
    # ユーザーがマウスドラッグ操作中でない場合のみ更新
    if ([System.Windows.Forms.Control]::MouseButtons -eq [System.Windows.Forms.MouseButtons]::None) {
        UpdateMasterUI
        UpdateMicUI

        $sel = $cmbApps.SelectedItem
        if ($sel -ne $null -and $sel.ProcessId -ne -1) {
            $mute = [LogVolumeApp.CoreAudio]::GetSessionMute($sel.ProcessId)
            UpdateAppMuteButton $mute
        }
    }
})
$timerSync.Start()

$form.Add_FormClosing({
    $timerSync.Stop()
    $timerSync.Dispose()
})

# 初期ロード
UpdateMasterUI
UpdateMicUI
RefreshAppList

# フォーム表示
[System.Windows.Forms.Application]::Run($form)
