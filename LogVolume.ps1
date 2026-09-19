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
using System.Drawing;
using System.Windows.Forms;

namespace LogVolumeApp {
    [Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceCollection {
        [PreserveSig] int GetCount(out uint count);
        [PreserveSig] int Item(uint index, out IMMDevice device);
    }

    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceEnumerator {
        [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
        [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
    }

    [Guid("9c2c4058-23f5-41de-877a-df3af236a09e"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IConnector {
        [PreserveSig] int GetType(out int type);
        [PreserveSig] int GetDataFlow(out int flow);
        [PreserveSig] int ConnectTo(IConnector connectTo);
        [PreserveSig] int Disconnect();
        [PreserveSig] int IsConnected(out bool connected);
        [PreserveSig] int GetConnectedTo(out IConnector connectedTo);
        [PreserveSig] int GetConnectorIdConnectedTo([MarshalAs(UnmanagedType.LPWStr)] out string id);
        [PreserveSig] int GetDeviceIdConnectedTo([MarshalAs(UnmanagedType.LPWStr)] out string id);
    }

    [Guid("2A07407E-6497-4A18-9787-32F79BD0D98F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDeviceTopology {
        [PreserveSig] int GetConnectorCount(out uint count);
        [PreserveSig] int GetConnector(uint index, out IConnector connector);
        [PreserveSig] int GetSubunitCount(out uint count);
        [PreserveSig] int GetSubunit(uint index, out IntPtr subunit);
        [PreserveSig] int GetPartById(uint localId, out IPart part);
    }

    [Guid("AE2DE0E4-5BCA-4F2D-AA46-5D13F8FDB3A9"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPart {
        [PreserveSig] int GetName([MarshalAs(UnmanagedType.LPWStr)] out string name);
        [PreserveSig] int GetLocalId(out uint id);
        [PreserveSig] int GetGlobalId([MarshalAs(UnmanagedType.LPWStr)] out string id);
        [PreserveSig] int GetPartType(out int partType);
        [PreserveSig] int GetSubType(out Guid subType);
        [PreserveSig] int GetControlInterfaceCount(out uint count);
        [PreserveSig] int GetControlInterface(uint index, out IntPtr controlInterface);
        [PreserveSig] int EnumPartsIncoming(out IntPtr parts);
        [PreserveSig] int EnumPartsOutgoing(out IntPtr parts);
        [PreserveSig] int GetTopologyObject(out IDeviceTopology topology);
        [PreserveSig] int Activate(int clsCtx, ref Guid iid, [MarshalAs(UnmanagedType.IUnknown)] out object interfacePointer);
    }

    [Guid("7FB7B48F-531D-44A2-BCB3-5AD5A134B3DC"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioVolumeLevel {
        [PreserveSig] int GetChannelCount(out uint count);
        [PreserveSig] int GetLevelRange(uint channel, out float minLevelDB, out float maxLevelDB, out float stepping);
        [PreserveSig] int GetLevel(uint channel, out float levelDB);
        [PreserveSig] int SetLevel(uint channel, float levelDB, ref Guid eventContext);
        [PreserveSig] int SetLevelUniform(float levelDB, ref Guid eventContext);
        [PreserveSig] int SetLevelAllChannels(float[] levelsDB, uint channels, ref Guid eventContext);
    }

    [Guid("DF45AEEA-B74A-4B6B-AFAD-2366B6AA012E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioMute {
        [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid eventContext);
        [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
    }

    [Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioMeterInformation {
        [PreserveSig] int GetPeakValue(out float peak);
        [PreserveSig] int GetMeteringChannelCount(out uint channelCount);
        [PreserveSig] int GetChannelsPeakValues(uint channelCount, [In, Out] float[] peakValues);
        [PreserveSig] int QueryHardwareSupport(out uint hardwareSupportMask);
    }

    public class AudioMeterBar : Control {
        public AudioMeterBar() {
            this.DoubleBuffered = true;
            this.SetStyle(ControlStyles.AllPaintingInWmPaint |
                          ControlStyles.UserPaint |
                          ControlStyles.OptimizedDoubleBuffer, true);
            this.BgColor = Color.FromArgb(40, 40, 40);
            this.GreenColor = Color.FromArgb(40, 180, 80);
            this.YellowColor = Color.FromArgb(230, 180, 20);
            this.RedColor = Color.FromArgb(230, 50, 50);
        }
        private float currentPeak = 0f;
        public float Peak { get; set; }
        public Color BgColor { get; set; }
        public Color GreenColor { get; set; }
        public Color YellowColor { get; set; }
        public Color RedColor { get; set; }

        public void SetPeakWithDecay(float newPeak) {
            if (newPeak >= currentPeak) {
                currentPeak = newPeak;
            } else {
                currentPeak = currentPeak * 0.82f;
                if (currentPeak < 0.001f) currentPeak = 0f;
            }
            this.Peak = currentPeak;
        }

        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e);
            var g = e.Graphics;
            int w = this.Width;
            int h = this.Height;
            using (var br = new SolidBrush(BgColor)) {
                g.FillRectangle(br, 0, 0, w, h);
            }
            if (Peak <= 0.0001f) return;
            float p = Peak > 1f ? 1f : Peak;
            int barW = (int)(w * p);
            if (barW <= 0) return;

            int greenEnd = (int)(w * 0.70f);
            int yellowEnd = (int)(w * 0.90f);

            int drawG = Math.Min(barW, greenEnd);
            if (drawG > 0) {
                using (var br = new SolidBrush(GreenColor)) {
                    g.FillRectangle(br, 0, 0, drawG, h);
                }
            }
            if (barW > greenEnd) {
                int drawY = Math.Min(barW, yellowEnd) - greenEnd;
                using (var br = new SolidBrush(YellowColor)) {
                    g.FillRectangle(br, greenEnd, 0, drawY, h);
                }
            }
            if (barW > yellowEnd) {
                int drawR = barW - yellowEnd;
                using (var br = new SolidBrush(RedColor)) {
                    g.FillRectangle(br, yellowEnd, 0, drawR, h);
                }
            }
        }
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
        // 正しい公式COMシグネチャ: HRESULT IsSystemSoundsSession(void);
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
        private static IMMDevice GetDefaultRenderEndpoint(out IMMDeviceEnumerator enumerator) {
            enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
            IMMDevice dev = null;
            enumerator.GetDefaultAudioEndpoint(0, 1, out dev);
            return dev;
        }

        private static IMMDevice GetDefaultCaptureEndpoint(out IMMDeviceEnumerator enumerator) {
            enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
            IMMDevice dev = null;
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
        // 1. マスター音量 (スピーカー / 出力)
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
        // 2. マイク音量 (入力 / キャプチャ)
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
        // 3. アプリケーション音量セッション
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

        public static IPart GetSidetonePart(uint id) {
            IMMDeviceEnumerator enumerator = null;
            IMMDeviceCollection col = null;
            try {
                enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
                enumerator.EnumAudioEndpoints(0, 1, out col);
                uint count = 0;
                if (col != null) col.GetCount(out count);
                for (uint i = 0; i < count; i++) {
                    IMMDevice dev = null;
                    col.Item(i, out dev);
                    if (dev == null) continue;

                    string name = "";
                    IPropertyStore store = null;
                    dev.OpenPropertyStore(0, out store);
                    if (store != null) {
                        PropertyKey key = new PropertyKey(new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"), 14);
                        PropVariant pv = new PropVariant();
                        store.GetValue(ref key, out pv);
                        name = Marshal.PtrToStringUni(pv.pwszVal) ?? "";
                        Marshal.ReleaseComObject(store);
                    }

                    if (name.IndexOf("USB audio CODEC", StringComparison.OrdinalIgnoreCase) >= 0) {
                        Guid iidTopo = typeof(IDeviceTopology).GUID;
                        object objTopo = null;
                        dev.Activate(ref iidTopo, 1, IntPtr.Zero, out objTopo);
                        IDeviceTopology epTopo = objTopo as IDeviceTopology;
                        if (epTopo != null) {
                            IConnector epConn = null;
                            epTopo.GetConnector(0, out epConn);
                            if (epConn != null) {
                                IConnector hwConn = null;
                                epConn.GetConnectedTo(out hwConn);
                                if (hwConn != null) {
                                    IPart hwPart = hwConn as IPart;
                                    if (hwPart != null) {
                                        IDeviceTopology hwTopo = null;
                                        hwPart.GetTopologyObject(out hwTopo);
                                        if (hwTopo != null) {
                                            IPart part = null;
                                            hwTopo.GetPartById(id, out part);
                                            return part;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {}
            return null;
        }

        public static float GetSidetoneVolume() {
            IPart part = GetSidetonePart(131074);
            if (part != null) {
                Guid iidVol = typeof(IAudioVolumeLevel).GUID;
                object objVol = null;
                part.Activate(1, ref iidVol, out objVol);
                var vol = objVol as IAudioVolumeLevel;
                if (vol != null) {
                    float level = 0;
                    vol.GetLevel(0, out level);
                    return level;
                }
            }
            return -1000f; // invalid
        }
        
        public static void SetSidetoneVolume(float level) {
            IPart part = GetSidetonePart(131074);
            if (part != null) {
                Guid iidVol = typeof(IAudioVolumeLevel).GUID;
                object objVol = null;
                part.Activate(1, ref iidVol, out objVol);
                var vol = objVol as IAudioVolumeLevel;
                if (vol != null) {
                    Guid ctx = Guid.Empty;
                    vol.SetLevel(0, level, ref ctx);
                }
            }
        }

        public static bool GetSidetoneMute() {
            IPart part = GetSidetonePart(131073);
            if (part != null) {
                Guid iidMute = typeof(IAudioMute).GUID;
                object objMute = null;
                part.Activate(1, ref iidMute, out objMute);
                var mute = objMute as IAudioMute;
                if (mute != null) {
                    bool val = false;
                    mute.GetMute(out val);
                    return val;
                }
            }
            return false;
        }
        
        public static void SetSidetoneMute(bool val) {
            IPart part = GetSidetonePart(131073);
            if (part != null) {
                Guid iidMute = typeof(IAudioMute).GUID;
                object objMute = null;
                part.Activate(1, ref iidMute, out objMute);
                var mute = objMute as IAudioMute;
                if (mute != null) {
                    Guid ctx = Guid.Empty;
                    mute.SetMute(val, ref ctx);
                }
            }
        }
        
        public static bool IsSidetoneAvailable() {
            return GetSidetonePart(131074) != null;
        }

        public static float GetMasterPeak() {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            try {
                dev = GetDefaultRenderEndpoint(out enumerator);
                if (dev == null) return 0f;
                Guid iid = typeof(IAudioMeterInformation).GUID;
                object obj;
                dev.Activate(ref iid, 1, IntPtr.Zero, out obj);
                var meter = obj as IAudioMeterInformation;
                if (meter == null) return 0f;
                float peak = 0f;
                meter.GetPeakValue(out peak);
                return peak;
            } catch { return 0f; }
            finally {
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static float GetMicPeak() {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            try {
                dev = GetDefaultCaptureEndpoint(out enumerator);
                if (dev == null) return 0f;
                Guid iid = typeof(IAudioMeterInformation).GUID;
                object obj;
                dev.Activate(ref iid, 1, IntPtr.Zero, out obj);
                var meter = obj as IAudioMeterInformation;
                if (meter == null) return 0f;
                float peak = 0f;
                meter.GetPeakValue(out peak);
                return peak;
            } catch { return 0f; }
            finally {
                if (dev != null) Marshal.ReleaseComObject(dev);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static float GetSessionPeak(int targetPid) {
            if (targetPid == -1) {
                return GetMasterPeak();
            }
            IMMDeviceEnumerator enumerator = null;
            IMMDevice dev = null;
            IAudioSessionManager2 mgr = null;
            IAudioSessionEnumerator sessionEnum = null;
            try {
                dev = GetDefaultRenderEndpoint(out enumerator);
                if (dev == null) return 0f;
                Guid IID_Mgr = typeof(IAudioSessionManager2).GUID;
                object obj;
                dev.Activate(ref IID_Mgr, 1, IntPtr.Zero, out obj);
                mgr = obj as IAudioSessionManager2;
                if (mgr == null) return 0f;

                mgr.GetSessionEnumerator(out sessionEnum);
                if (sessionEnum == null) return 0f;

                int count;
                sessionEnum.GetCount(out count);
                for (int i = 0; i < count; i++) {
                    IAudioSessionControl2 ctl = null;
                    try {
                        sessionEnum.GetSession(i, out ctl);
                        if (ctl == null) continue;

                        int pid = 0;
                        ctl.GetProcessId(out pid);
                        if (pid == targetPid) {
                            var meter = ctl as IAudioMeterInformation;
                            if (meter != null) {
                                float peak = 0f;
                                meter.GetPeakValue(out peak);
                                return peak;
                            }
                        }
                    } finally {
                        if (ctl != null) Marshal.ReleaseComObject(ctl);
                    }
                }
                return 0f;
            } catch { return 0f; }
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

Add-Type -TypeDefinition $csharp -ReferencedAssemblies System.Windows.Forms, System.Drawing

# --- GUI構築 ---
# --- テーマ判定 ---
$isLight = $false
try {
    $regKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    $val = Get-ItemProperty -Path $regKey -Name 'AppsUseLightTheme' -ErrorAction SilentlyContinue
    if ($val -ne $null -and $val.AppsUseLightTheme -eq 1) {
        $isLight = $true
    }
} catch {}

if ($isLight) {
    $cFormBg = [System.Drawing.Color]::FromArgb(245, 245, 245)
    $cFormFg = [System.Drawing.Color]::Black
    $cGrpMaster = [System.Drawing.Color]::FromArgb(0, 50, 150)
    $cGrpApp = [System.Drawing.Color]::FromArgb(0, 100, 60)
    $cGrpMic = [System.Drawing.Color]::FromArgb(150, 70, 0)
    $cBtnBg = [System.Drawing.Color]::FromArgb(225, 225, 225)
    $cBtnFg = [System.Drawing.Color]::Black
    $cBtnMuteOn = [System.Drawing.Color]::FromArgb(255, 120, 120)
    $cPresetsMasterBg = [System.Drawing.Color]::FromArgb(215, 225, 240)
    $cPresetsMasterFg = [System.Drawing.Color]::FromArgb(0, 40, 100)
    $cPresetsAppBg = [System.Drawing.Color]::FromArgb(215, 240, 225)
    $cPresetsAppFg = [System.Drawing.Color]::FromArgb(0, 80, 40)
    $cPresetsMicBg = [System.Drawing.Color]::FromArgb(245, 225, 210)
    $cPresetsMicFg = [System.Drawing.Color]::FromArgb(120, 50, 0)
    $cComboBg = [System.Drawing.Color]::White
    $cPresetHint = [System.Drawing.Color]::FromArgb(180, 80, 0)
    $cNote = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $cMicName = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $cMeterBg = [System.Drawing.Color]::FromArgb(215, 215, 215)
} else {
    $cFormBg = [System.Drawing.Color]::FromArgb(28, 28, 30)
    $cFormFg = [System.Drawing.Color]::White
    $cGrpMaster = [System.Drawing.Color]::FromArgb(180, 210, 255)
    $cGrpApp = [System.Drawing.Color]::FromArgb(180, 255, 210)
    $cGrpMic = [System.Drawing.Color]::FromArgb(255, 210, 160)
    $cBtnBg = [System.Drawing.Color]::FromArgb(55, 55, 60)
    $cBtnFg = [System.Drawing.Color]::White
    $cBtnMuteOn = [System.Drawing.Color]::FromArgb(160, 45, 45)
    $cPresetsMasterBg = [System.Drawing.Color]::FromArgb(45, 45, 50)
    $cPresetsMasterFg = [System.Drawing.Color]::FromArgb(210, 220, 235)
    $cPresetsAppBg = [System.Drawing.Color]::FromArgb(35, 50, 40)
    $cPresetsAppFg = [System.Drawing.Color]::FromArgb(180, 255, 200)
    $cPresetsMicBg = [System.Drawing.Color]::FromArgb(50, 45, 40)
    $cPresetsMicFg = [System.Drawing.Color]::FromArgb(240, 220, 200)
    $cComboBg = [System.Drawing.Color]::FromArgb(40, 40, 45)
    $cPresetHint = [System.Drawing.Color]::FromArgb(255, 220, 120)
    $cNote = [System.Drawing.Color]::FromArgb(150, 150, 150)
    $cMicName = [System.Drawing.Color]::FromArgb(200, 200, 200)
    $cMeterBg = [System.Drawing.Color]::FromArgb(45, 45, 50)
}
$form = New-Object System.Windows.Forms.Form
$form.Text = "LogVolume - 対数音量ミキサー"
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = $cFormBg
$form.ForeColor = $cFormFg
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

# ==========================================
# 1. マスター音量グループ (全体 / 出力)
# ==========================================
$grpMaster = New-Object System.Windows.Forms.GroupBox
$grpMaster.Text = " 1. マスター音量 (全体 / 出力) "
$grpMaster.Location = New-Object System.Drawing.Point(15, 38)
$grpMaster.Size = New-Object System.Drawing.Size(465, 175)
$grpMaster.ForeColor = $cGrpMaster

$lblMasterVal = New-Object System.Windows.Forms.Label
$lblMasterVal.Location = New-Object System.Drawing.Point(15, 24)
$lblMasterVal.Size = New-Object System.Drawing.Size(320, 24)
$lblMasterVal.Font = New-Object System.Drawing.Font("Meiryo UI", 10, [System.Drawing.FontStyle]::Bold)
$lblMasterVal.ForeColor = $cFormFg
$grpMaster.Controls.Add($lblMasterVal)

$btnMasterMute = New-Object System.Windows.Forms.Button
$btnMasterMute.Location = New-Object System.Drawing.Point(345, 18)
$btnMasterMute.Size = New-Object System.Drawing.Size(105, 30)
$btnMasterMute.FlatStyle = "Flat"
$btnMasterMute.BackColor = $cBtnBg
$btnMasterMute.ForeColor = $cBtnFg
$grpMaster.Controls.Add($btnMasterMute)

$trackMaster = New-Object System.Windows.Forms.TrackBar
$trackMaster.Location = New-Object System.Drawing.Point(10, 54)
$trackMaster.Size = New-Object System.Drawing.Size(445, 45)
$trackMaster.Minimum = -120 # -60 dB (0.5 dB刻み)
$trackMaster.Maximum = 0    # 0 dB
$trackMaster.TickFrequency = 10
$grpMaster.Controls.Add($trackMaster)

$meterMaster = New-Object LogVolumeApp.AudioMeterBar
$meterMaster.Location = New-Object System.Drawing.Point(18, 98)
$meterMaster.Size = New-Object System.Drawing.Size(430, 6)
$meterMaster.BgColor = $cMeterBg
$grpMaster.Controls.Add($meterMaster)

# マスタープリセット
$pnlMasterPresets = New-Object System.Windows.Forms.Panel
$pnlMasterPresets.Location = New-Object System.Drawing.Point(10, 110)
$pnlMasterPresets.Size = New-Object System.Drawing.Size(445, 52)

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
    $btn.Size = New-Object System.Drawing.Size(85, 34)
    $btn.Location = New-Object System.Drawing.Point($mx, 4)
    $btn.FlatStyle = "Flat"
    $btn.BackColor = $cPresetsMasterBg
    $btn.ForeColor = $cPresetsMasterFg
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

# ==========================================
# 2. アプリケーション音量グループ (対数・微小調整) ※順序入れ替え
# ==========================================
$grpApp = New-Object System.Windows.Forms.GroupBox
$grpApp.Text = " 2. アプリケーション音量 (対数・微小調整) "
$grpApp.Location = New-Object System.Drawing.Point(15, 222)
$grpApp.Size = New-Object System.Drawing.Size(465, 275)
$grpApp.ForeColor = $cGrpApp

$lblAppSelect = New-Object System.Windows.Forms.Label
$lblAppSelect.Text = "対象アプリ:"
$lblAppSelect.Location = New-Object System.Drawing.Point(15, 24)
$lblAppSelect.Size = New-Object System.Drawing.Size(72, 20)
$grpApp.Controls.Add($lblAppSelect)

$cmbApps = New-Object System.Windows.Forms.ComboBox
$cmbApps.Location = New-Object System.Drawing.Point(88, 20)
$cmbApps.Size = New-Object System.Drawing.Size(232, 26)
$cmbApps.DropDownStyle = "DropDownList"
$cmbApps.BackColor = $cComboBg
$cmbApps.ForeColor = $cFormFg
$grpApp.Controls.Add($cmbApps)

$btnAppMute = New-Object System.Windows.Forms.Button
$btnAppMute.Text = "消音"
$btnAppMute.Location = New-Object System.Drawing.Point(328, 18)
$btnAppMute.Size = New-Object System.Drawing.Size(62, 28)
$btnAppMute.FlatStyle = "Flat"
$btnAppMute.BackColor = $cBtnBg
$btnAppMute.ForeColor = $cBtnFg
$grpApp.Controls.Add($btnAppMute)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "更新"
$btnRefresh.Location = New-Object System.Drawing.Point(396, 18)
$btnRefresh.Size = New-Object System.Drawing.Size(54, 28)
$btnRefresh.FlatStyle = "Flat"
$btnRefresh.BackColor = $cBtnBg
$btnRefresh.ForeColor = $cBtnFg
$grpApp.Controls.Add($btnRefresh)

$lblAppVal = New-Object System.Windows.Forms.Label
$lblAppVal.Location = New-Object System.Drawing.Point(15, 56)
$lblAppVal.Size = New-Object System.Drawing.Size(435, 24)
$lblAppVal.Font = New-Object System.Drawing.Font("Meiryo UI", 10, [System.Drawing.FontStyle]::Bold)
$lblAppVal.ForeColor = $cFormFg
$grpApp.Controls.Add($lblAppVal)

$trackApp = New-Object System.Windows.Forms.TrackBar
$trackApp.Location = New-Object System.Drawing.Point(10, 84)
$trackApp.Size = New-Object System.Drawing.Size(445, 45)
$trackApp.Minimum = -120 # -60 dB (0.5 dB刻み)
$trackApp.Maximum = 0    # 0 dB
$trackApp.TickFrequency = 10
$grpApp.Controls.Add($trackApp)

$meterApp = New-Object LogVolumeApp.AudioMeterBar
$meterApp.Location = New-Object System.Drawing.Point(18, 127)
$meterApp.Size = New-Object System.Drawing.Size(430, 6)
$meterApp.BgColor = $cMeterBg
$grpApp.Controls.Add($meterApp)

# アプリ微小音量プリセット
$lblPresetHint = New-Object System.Windows.Forms.Label
$lblPresetHint.Text = "★ 微小音量プリセット (Windows標準の1%以下の世界):"
$lblPresetHint.Location = New-Object System.Drawing.Point(15, 134)
$lblPresetHint.Size = New-Object System.Drawing.Size(435, 20)
$lblPresetHint.ForeColor = $cPresetHint
$grpApp.Controls.Add($lblPresetHint)

$pnlAppPresets = New-Object System.Windows.Forms.Panel
$pnlAppPresets.Location = New-Object System.Drawing.Point(10, 156)
$pnlAppPresets.Size = New-Object System.Drawing.Size(445, 48)

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
    $btn.Size = New-Object System.Drawing.Size(85, 36)
    $btn.Location = New-Object System.Drawing.Point($ax, 4)
    $btn.FlatStyle = "Flat"
    $btn.BackColor = $cPresetsAppBg
    $btn.ForeColor = $cPresetsAppFg
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
$lblNote.Text = "※「全アプリ一括適用」時は新規起動アプリにも自動で本音量が適用されます。"
$lblNote.Location = New-Object System.Drawing.Point(15, 210)
$lblNote.Size = New-Object System.Drawing.Size(435, 55)
$lblNote.ForeColor = $cNote
$lblNote.Font = New-Object System.Drawing.Font("Meiryo UI", 8.25)
$grpApp.Controls.Add($lblNote)

$form.Controls.Add($grpApp)

# ==========================================
# 3. マイク音量グループ (入力) ※順序入れ替え
# ==========================================
$grpMic = New-Object System.Windows.Forms.GroupBox
$grpMic.Text = " 3. マイク音量 (入力) "
$grpMic.Location = New-Object System.Drawing.Point(15, 507)
$grpMic.Size = New-Object System.Drawing.Size(465, 175)
$grpMic.ForeColor = $cGrpMic

$lblMicName = New-Object System.Windows.Forms.Label
$lblMicName.Location = New-Object System.Drawing.Point(15, 20)
$lblMicName.Size = New-Object System.Drawing.Size(320, 18)
$lblMicName.ForeColor = $cMicName
$lblMicName.Font = New-Object System.Drawing.Font("Meiryo UI", 8.25)
$grpMic.Controls.Add($lblMicName)

$lblMicVal = New-Object System.Windows.Forms.Label
$lblMicVal.Location = New-Object System.Drawing.Point(15, 38)
$lblMicVal.Size = New-Object System.Drawing.Size(320, 24)
$lblMicVal.Font = New-Object System.Drawing.Font("Meiryo UI", 10, [System.Drawing.FontStyle]::Bold)
$lblMicVal.ForeColor = $cFormFg
$grpMic.Controls.Add($lblMicVal)

$btnMicMute = New-Object System.Windows.Forms.Button
$btnMicMute.Location = New-Object System.Drawing.Point(345, 22)
$btnMicMute.Size = New-Object System.Drawing.Size(105, 30)
$btnMicMute.FlatStyle = "Flat"
$btnMicMute.BackColor = $cBtnBg
$btnMicMute.ForeColor = $cBtnFg
$grpMic.Controls.Add($btnMicMute)

$trackMic = New-Object System.Windows.Forms.TrackBar
$trackMic.Location = New-Object System.Drawing.Point(10, 66)
$trackMic.Size = New-Object System.Drawing.Size(445, 45)
$trackMic.Minimum = 0   # 0 %
$trackMic.Maximum = 100 # 100 %
$trackMic.TickFrequency = 10
$grpMic.Controls.Add($trackMic)

$meterMic = New-Object LogVolumeApp.AudioMeterBar
$meterMic.Location = New-Object System.Drawing.Point(18, 107)
$meterMic.Size = New-Object System.Drawing.Size(430, 6)
$meterMic.BgColor = $cMeterBg
$grpMic.Controls.Add($meterMic)

# マイクプリセット
$pnlMicPresets = New-Object System.Windows.Forms.Panel
$pnlMicPresets.Location = New-Object System.Drawing.Point(10, 116)
$pnlMicPresets.Size = New-Object System.Drawing.Size(445, 48)

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
    $btn.Size = New-Object System.Drawing.Size(85, 34)
    $btn.Location = New-Object System.Drawing.Point($ux, 4)
    $btn.FlatStyle = "Flat"
    $btn.BackColor = $cPresetsMicBg
    $btn.ForeColor = $cPresetsMicFg
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

# フォームのクライアントサイズを底辺マージン15pxに合わせて設定（下の無駄なスペースを完全解消）
$form.ClientSize = New-Object System.Drawing.Size(495, 885)

# ==========================================
# 4. ダイレクトモニタリング (Earthworks Icon)
# ==========================================
$grpSidetone = New-Object System.Windows.Forms.GroupBox
$grpSidetone.Text = " 4. ダイレクトモニタリング (Earthworks Icon) "
$grpSidetone.Location = New-Object System.Drawing.Point(15, 692)
$grpSidetone.Size = New-Object System.Drawing.Size(465, 175)
$grpSidetone.ForeColor = $cGrpMic

$lblSidetoneName = New-Object System.Windows.Forms.Label
$lblSidetoneName.Location = New-Object System.Drawing.Point(15, 20)
$lblSidetoneName.Size = New-Object System.Drawing.Size(320, 18)
$lblSidetoneName.ForeColor = $cMicName
$lblSidetoneName.Font = New-Object System.Drawing.Font("Meiryo UI", 8.25)
$grpSidetone.Controls.Add($lblSidetoneName)

$lblSidetoneVal = New-Object System.Windows.Forms.Label
$lblSidetoneVal.Location = New-Object System.Drawing.Point(15, 38)
$lblSidetoneVal.Size = New-Object System.Drawing.Size(320, 24)
$lblSidetoneVal.Font = New-Object System.Drawing.Font("Meiryo UI", 10, [System.Drawing.FontStyle]::Bold)
$lblSidetoneVal.ForeColor = $cFormFg
$grpSidetone.Controls.Add($lblSidetoneVal)

$btnSidetoneMute = New-Object System.Windows.Forms.Button
$btnSidetoneMute.Location = New-Object System.Drawing.Point(345, 22)
$btnSidetoneMute.Size = New-Object System.Drawing.Size(105, 30)
$btnSidetoneMute.FlatStyle = "Flat"
$btnSidetoneMute.BackColor = $cBtnBg
$btnSidetoneMute.ForeColor = $cBtnFg
$grpSidetone.Controls.Add($btnSidetoneMute)

$trackSidetone = New-Object System.Windows.Forms.TrackBar
$trackSidetone.Location = New-Object System.Drawing.Point(10, 68)
$trackSidetone.Size = New-Object System.Drawing.Size(445, 45)
$trackSidetone.Minimum = -120
$trackSidetone.Maximum = 0
$trackSidetone.TickFrequency = 10
$grpSidetone.Controls.Add($trackSidetone)

$meterSidetone = New-Object LogVolumeApp.AudioMeterBar
$meterSidetone.Location = New-Object System.Drawing.Point(18, 107)
$meterSidetone.Size = New-Object System.Drawing.Size(430, 6)
$meterSidetone.BgColor = $cMeterBg
$grpSidetone.Controls.Add($meterSidetone)

$pnlSidetonePresets = New-Object System.Windows.Forms.Panel
$pnlSidetonePresets.Location = New-Object System.Drawing.Point(10, 115)
$pnlSidetonePresets.Size = New-Object System.Drawing.Size(445, 42)

$sidetonePresets = @(
    @{ Text = "消音";  Db = -120 },
    @{ Text = "25%"; Db = -12.0 },
    @{ Text = "50%"; Db = -6.0 },
    @{ Text = "75%"; Db = -2.5 },
    @{ Text = "100%";Db = 0.0 }
)
$sx = 5
foreach ($p in $sidetonePresets) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $p.Text
    $btn.Size = New-Object System.Drawing.Size(85, 34)
    $btn.Location = New-Object System.Drawing.Point($sx, 4)
    $btn.FlatStyle = "Flat"
    $btn.BackColor = $cPresetsMicBg
    $btn.ForeColor = $cPresetsMicFg
    $targetDb = $p.Db
    $btn.Add_Click({
        [LogVolumeApp.CoreAudio]::SetSidetoneVolume($targetDb)
        UpdateSidetoneUI
    }.GetNewClosure())
    $pnlSidetonePresets.Controls.Add($btn)
    $sx += 88
}
$grpSidetone.Controls.Add($pnlSidetonePresets)
$form.Controls.Add($grpSidetone)

$trackSidetone.Add_Scroll({
    $db = $trackSidetone.Value / 2.0
    [LogVolumeApp.CoreAudio]::SetSidetoneVolume($db)
    UpdateSidetoneUI
})

$btnSidetoneMute.Add_Click({
    $mute = [LogVolumeApp.CoreAudio]::GetSidetoneMute()
    [LogVolumeApp.CoreAudio]::SetSidetoneMute(-not $mute)
    UpdateSidetoneUI
})

# ==========================================
# UI更新ロジック
# ==========================================
function UpdateMasterUI {
    $db = [LogVolumeApp.CoreAudio]::GetMasterDb()
    $scalar = [LogVolumeApp.CoreAudio]::GetMasterScalar()
    $pct = [math]::Round($scalar * 100, 1)
    $lblMasterVal.Text = "現在: {0} dB ({1}%)" -f ([math]::Round($db, 1)), $pct

    $val = [int]($db * 2)
    if ($val -lt -120) { $val = -120 }
    if ($val -gt 0) { $val = 0 }
    if ($trackMaster.Value -ne $val) {
        $trackMaster.Value = $val
    }

    $mute = [LogVolumeApp.CoreAudio]::GetMasterMute()
    $btnMasterMute.Text = if ($mute) { "ミュート中" } else { "ミュート" }
    $btnMasterMute.BackColor = if ($mute) { $cBtnMuteOn } else { $cBtnBg }
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
    $dbSign = if ($db -ge 0) { "+{0}" -f [math]::Round($db, 1) } else { "{0}" -f [math]::Round($db, 1) }
    $lblMicVal.Text = "現在: {0}% ({1} dB)" -f $pct, $dbSign

    if ($trackMic.Value -ne $pct) {
        $trackMic.Value = $pct
    }

    $mute = [LogVolumeApp.CoreAudio]::GetMicMute()
    $btnMicMute.Text = if ($mute) { "ミュート中" } else { "ミュート" }
    $btnMicMute.BackColor = if ($mute) { $cBtnMuteOn } else { $cBtnBg }
}

function UpdateAppMuteButton($mute) {
    $btnAppMute.Text = if ($mute) { "消音中" } else { "消音" }
    $btnAppMute.BackColor = if ($mute) { $cBtnMuteOn } else { $cBtnBg }
}

function UpdateSidetoneUI {
    if (-not [LogVolumeApp.CoreAudio]::IsSidetoneAvailable()) {
        $lblSidetoneName.Text = "デバイス: 未検出 (Earthworks Icon非接続)"
        $lblSidetoneVal.Text = "現在: --"
        $trackSidetone.Enabled = $false
        $btnSidetoneMute.Enabled = $false
        $pnlSidetonePresets.Enabled = $false
        return
    }

    $lblSidetoneName.Text = "デバイス: Earthworks Icon (マイクモニター)"
    $trackSidetone.Enabled = $true
    $btnSidetoneMute.Enabled = $true
    $pnlSidetonePresets.Enabled = $true

    $db = [LogVolumeApp.CoreAudio]::GetSidetoneVolume()
    $lblSidetoneVal.Text = "現在: {0} dB" -f [math]::Round($db, 1)

    $val = [int]($db * 2)
    if ($val -lt -120) { $val = -120 }
    if ($val -gt 0) { $val = 0 }
    if ($trackSidetone.Value -ne $val) {
        $trackSidetone.Value = $val
    }

    $mute = [LogVolumeApp.CoreAudio]::GetSidetoneMute()
    $btnSidetoneMute.Text = if ($mute) { "ミュート中" } else { "ミュート" }
    $btnSidetoneMute.BackColor = if ($mute) { $cBtnMuteOn } else { $cBtnBg }
}

$script:knownSessionPids = New-Object 'System.Collections.Generic.HashSet[int]'

function RefreshAppList {
    $currentSelectedPid = -999
    if ($cmbApps.SelectedItem -ne $null) {
        $currentSelectedPid = $cmbApps.SelectedItem.ProcessId
    }

    $cmbApps.BeginUpdate()
    $cmbApps.Items.Clear()

    # 「全アプリ一括適用」項目
    $allItem = New-Object LogVolumeApp.AppSessionItem
    $allItem.ProcessId = -1
    $allItem.DisplayName = "全アプリ一括適用"
    $allItem.VolumeScalar = 1.0
    $allItem.VolumeDb = 0.0
    $allItem.IsMuted = $false
    [void]$cmbApps.Items.Add($allItem)

    $sessions = [LogVolumeApp.CoreAudio]::GetSessions()
    $selectedIdx = -1
    $i = 1
    foreach ($s in $sessions) {
        [void]$script:knownSessionPids.Add($s.ProcessId)
        [void]$cmbApps.Items.Add($s)
        if ($s.ProcessId -eq $currentSelectedPid) {
            $selectedIdx = $i
        }
        $i++
    }
    $cmbApps.EndUpdate()

    if ($selectedIdx -ge 0) {
        $cmbApps.SelectedIndex = $selectedIdx
    } else {
        $cmbApps.SelectedIndex = 0
    }

    UpdateAppUIFromSelection
}

function UpdateAppUIFromSelection {
    $sel = $cmbApps.SelectedItem
    if ($sel -eq $null) { return }

    if ($sel.ProcessId -eq -1) {
        $db = $trackApp.Value / 2.0
        $scalar = [math]::Pow(10.0, $db / 20.0)
        $pct = [math]::Round($scalar * 100, 1)
        $lblAppVal.Text = "現在: {0} dB ({1}%)" -f ([math]::Round($db, 1)), $pct
        UpdateAppMuteButton $false
        return
    }

    $db = [LogVolumeApp.CoreAudio]::GetSessionDb($sel.ProcessId)
    $scalar = [LogVolumeApp.CoreAudio]::GetSessionScalar($sel.ProcessId)
    $muted = [LogVolumeApp.CoreAudio]::GetSessionMute($sel.ProcessId)
    $pct = [math]::Round($scalar * 100, 1)
    $lblAppVal.Text = "{0}: {1} dB ({2}%)" -f $sel.DisplayName, ([math]::Round($db, 1)), $pct
    
    $val = [int]($db * 2)
    if ($val -lt -120) { $val = -120 }
    if ($val -gt 0) { $val = 0 }
    if ($trackApp.Value -ne $val) {
        $trackApp.Value = $val
    }
    UpdateAppMuteButton $muted
}

function ApplyAppVolumeFromTrackbar {
    $db = $trackApp.Value / 2.0
    $scalar = [math]::Pow(10.0, $db / 20.0)
    $pct = [math]::Round($scalar * 100, 1)

    $sel = $cmbApps.SelectedItem
    if ($sel -eq $null) { return }

    if ($sel.ProcessId -eq -1) {
        [LogVolumeApp.CoreAudio]::SetSessionScalar(-1, $scalar)
        $lblAppVal.Text = "現在: {0} dB ({1}%)" -f ([math]::Round($db, 1)), $pct
        return
    }

    [LogVolumeApp.CoreAudio]::SetSessionDb($sel.ProcessId, $db)
    $lblAppVal.Text = "{0}: {1} dB ({2}%)" -f $sel.DisplayName, ([math]::Round($db, 1)), $pct
}

# ==========================================
# イベントハンドラ
# ==========================================
# スライダー操作時はトラックバーを強制上書きせず、音量設定とラベル更新のみ行う（ジッター防止）
$trackMaster.Add_Scroll({
    $db = $trackMaster.Value / 2.0
    [LogVolumeApp.CoreAudio]::SetMasterDb($db)
    $scalar = [LogVolumeApp.CoreAudio]::GetMasterScalar()
    $pct = [math]::Round($scalar * 100, 1)
    $lblMasterVal.Text = "現在: {0} dB ({1}%)" -f ([math]::Round($db, 1)), $pct
})

$btnMasterMute.Add_Click({
    $mute = [LogVolumeApp.CoreAudio]::GetMasterMute()
    [LogVolumeApp.CoreAudio]::SetMasterMute(-not $mute)
    UpdateMasterUI
})

$trackApp.Add_Scroll({
    ApplyAppVolumeFromTrackbar
})

$btnAppMute.Add_Click({
    $sel = $cmbApps.SelectedItem
    if ($sel -eq $null) { return }

    if ($sel.ProcessId -eq -1) {
        $allMute = [LogVolumeApp.CoreAudio]::GetSessionMute(-1)
        [LogVolumeApp.CoreAudio]::SetSessionMute(-1, -not $allMute)
        UpdateAppUIFromSelection
        return
    }

    $currentMute = [LogVolumeApp.CoreAudio]::GetSessionMute($sel.ProcessId)
    [LogVolumeApp.CoreAudio]::SetSessionMute($sel.ProcessId, -not $currentMute)
    UpdateAppUIFromSelection
})

$btnRefresh.Add_Click({
    RefreshAppList
})

$cmbApps.Add_SelectedIndexChanged({
    UpdateAppUIFromSelection
})

$trackMic.Add_Scroll({
    $scalar = $trackMic.Value / 100.0
    [LogVolumeApp.CoreAudio]::SetMicScalar($scalar)
    $db = [LogVolumeApp.CoreAudio]::GetMicDb()
    $dbSign = if ($db -ge 0) { "+{0}" -f [math]::Round($db, 1) } else { "{0}" -f [math]::Round($db, 1) }
    $lblMicVal.Text = "現在: {0}% ({1} dB)" -f $trackMic.Value, $dbSign
})

$btnMicMute.Add_Click({
    $mute = [LogVolumeApp.CoreAudio]::GetMicMute()
    [LogVolumeApp.CoreAudio]::SetMicMute(-not $mute)
    UpdateMicUI
})

# ==========================================
# 外部変更の自動同期タイマー (リアルタイム追従)
# ==========================================
$timerSync = New-Object System.Windows.Forms.Timer
$timerSync.Interval = 1000
$timerSync.Add_Tick({
    # ユーザーがマウスドラッグ操作中でない場合のみ更新
    if ([System.Windows.Forms.Control]::MouseButtons -eq [System.Windows.Forms.MouseButtons]::None) {
        UpdateMasterUI
        UpdateMicUI
        UpdateSidetoneUI

        # 音声セッション（アプリ）の定期監視と新着アプリへの自動音量適用
        $currentSessions = [LogVolumeApp.CoreAudio]::GetSessions()
        $hasNewApp = $false
        $hasExitedApp = $false

        $currentPids = New-Object 'System.Collections.Generic.HashSet[int]'
        foreach ($s in $currentSessions) {
            [void]$currentPids.Add($s.ProcessId)
            if (-not $script:knownSessionPids.Contains($s.ProcessId)) {
                # 新規起動アプリを検出！
                $hasNewApp = $true
                [void]$script:knownSessionPids.Add($s.ProcessId)

                # 「全アプリ一括適用」が選択されている場合は、現在の設定音量を即時適用
                $sel = $cmbApps.SelectedItem
                if ($sel -ne $null -and $sel.ProcessId -eq -1) {
                    $db = $trackApp.Value / 2.0
                    [LogVolumeApp.CoreAudio]::SetSessionDb($s.ProcessId, $db)

                    if ($btnAppMute.Text -eq "消音中") {
                        [LogVolumeApp.CoreAudio]::SetSessionMute($s.ProcessId, $true)
                    }
                }
            }
        }

        # 終了したアプリを knownSessionPids から除外
        $removedPids = @()
        foreach ($kpid in $script:knownSessionPids) {
            if (-not $currentPids.Contains($kpid)) {
                $removedPids += $kpid
                $hasExitedApp = $true
            }
        }
        foreach ($rpid in $removedPids) {
            [void]$script:knownSessionPids.Remove($rpid)
        }

        # アプリの起動や終了があり、ドロップダウンメニューを展開中でない場合は一覧を更新
        if (($hasNewApp -or $hasExitedApp) -and -not $cmbApps.DroppedDown) {
            RefreshAppList
        }

        $sel = $cmbApps.SelectedItem
        if ($sel -ne $null -and $sel.ProcessId -ne -1) {
            $mute = [LogVolumeApp.CoreAudio]::GetSessionMute($sel.ProcessId)
            UpdateAppMuteButton $mute
        }
    }
})
$timerSync.Start()

# ==========================================
# 音声レベルメーター定期更新タイマー (約 30 FPS)
# ==========================================
$timerMeter = New-Object System.Windows.Forms.Timer
$timerMeter.Interval = 35
$timerMeter.Add_Tick({
    $pMaster = [LogVolumeApp.CoreAudio]::GetMasterPeak()
    $meterMaster.SetPeakWithDecay($pMaster)
    $meterMaster.Invalidate()

    $sel = $cmbApps.SelectedItem
    $targetPid = if ($sel -ne $null) { $sel.ProcessId } else { -1 }
    $pApp = [LogVolumeApp.CoreAudio]::GetSessionPeak($targetPid)
    $meterApp.SetPeakWithDecay($pApp)
    $meterApp.Invalidate()

    $pMic = [LogVolumeApp.CoreAudio]::GetMicPeak()
    $meterMic.SetPeakWithDecay($pMic)
    $meterMic.Invalidate()

    if ($meterSidetone -ne $null) {
        $meterSidetone.SetPeakWithDecay($pMic)
        $meterSidetone.Invalidate()
    }
})
$timerMeter.Start()

$form.Add_FormClosing({
    $timerSync.Stop()
    $timerSync.Dispose()
    $timerMeter.Stop()
    $timerMeter.Dispose()
})

# 初期化
UpdateMasterUI
UpdateMicUI
UpdateSidetoneUI
RefreshAppList

# フォーム表示
[System.Windows.Forms.Application]::Run($form)


