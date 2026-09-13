using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class ResolutionHelper {
    const int ENUM_CURRENT_SETTINGS = -1;
    const int DM_BITSPERPEL = 0x00040000;
    const int DM_PELSWIDTH = 0x00080000;
    const int DM_PELSHEIGHT = 0x00100000;
    const int DM_DISPLAYFREQUENCY = 0x00400000;
    const uint CDS_UPDATEREGISTRY = 0x00000001;
    const uint CDS_TEST = 0x00000002;
    const int DISP_CHANGE_SUCCESSFUL = 0;
    const int DISPLAY_DEVICE_ATTACHED_TO_DESKTOP = 0x00000001;
    const int DISPLAY_DEVICE_PRIMARY_DEVICE = 0x00000004;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct DISPLAY_DEVICE {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
        public int dmFields;
        public int dmPositionX, dmPositionY;
        public int dmDisplayOrientation, dmDisplayFixedOutput;
        public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
        public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType;
        public int dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool EnumDisplayDevices(string device, uint devNum, ref DISPLAY_DEVICE displayDevice, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool EnumDisplaySettingsEx(string deviceName, int modeNum, ref DEVMODE devMode, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int ChangeDisplaySettingsEx(string deviceName, ref DEVMODE devMode, IntPtr hwnd, uint flags, IntPtr lParam);

    static DEVMODE Current(string device) {
        var mode = new DEVMODE();
        mode.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
        if (!EnumDisplaySettingsEx(device, ENUM_CURRENT_SETTINGS, ref mode, 0))
            throw new InvalidOperationException("Unable to read current mode for " + device);
        return mode;
    }

    static int TestOrApply(string device, int width, int height, int hz, uint flags) {
        if (width < 640 || width > 16384 || height < 480 || height > 16384 || hz < 24 || hz > 1000) return -5;
        DEVMODE mode = Current(device);
        mode.dmPelsWidth = width;
        mode.dmPelsHeight = height;
        mode.dmDisplayFrequency = hz;
        mode.dmFields |= DM_PELSWIDTH | DM_PELSHEIGHT | DM_DISPLAYFREQUENCY | DM_BITSPERPEL;
        return ChangeDisplaySettingsEx(device, ref mode, IntPtr.Zero, flags, IntPtr.Zero);
    }

    static string ResultName(int code) {
        switch (code) {
            case 0: return "SUCCESS";
            case 1: return "RESTART";
            case -1: return "FAILED";
            case -2: return "BADMODE";
            case -3: return "NOTUPDATED";
            case -4: return "BADFLAGS";
            case -5: return "BADPARAM";
            case -6: return "BADDUALVIEW";
            default: return "CODE_" + code;
        }
    }

    static int EmitResult(int code) {
        Console.WriteLine("RESULT|" + code + "|" + ResultName(code));
        return code == DISP_CHANGE_SUCCESSFUL ? 0 : 3;
    }

    static int Probe() {
        uint i = 0;
        while (true) {
            var dd = new DISPLAY_DEVICE(); dd.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE));
            if (!EnumDisplayDevices(null, i++, ref dd, 0)) break;
            if ((dd.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) == 0) continue;
            try {
                DEVMODE mode = Current(dd.DeviceName);
                string primary = (dd.StateFlags & DISPLAY_DEVICE_PRIMARY_DEVICE) != 0 ? "1" : "0";
                Console.WriteLine("DEVICE|" + dd.DeviceName + "|" + mode.dmPelsWidth + "|" + mode.dmPelsHeight + "|" + mode.dmDisplayFrequency + "|" + mode.dmBitsPerPel + "|" + primary + "|" + dd.DeviceString);
            } catch { }
        }
        return 0;
    }

    public static int Main(string[] args) {
        try {
            if (args.Length == 1 && args[0].Equals("probe", StringComparison.OrdinalIgnoreCase)) return Probe();
            if (args.Length != 5) {
                Console.Error.WriteLine("Usage: 986ResolutionHelper.exe probe | test|apply-temp|apply-persist <device> <width> <height> <hz>");
                return 2;
            }
            string op = args[0], device = args[1];
            int width, height, hz;
            if (!int.TryParse(args[2], out width) || !int.TryParse(args[3], out height) || !int.TryParse(args[4], out hz)) return 2;
            if (op.Equals("test", StringComparison.OrdinalIgnoreCase)) return EmitResult(TestOrApply(device, width, height, hz, CDS_TEST));
            if (op.Equals("apply-temp", StringComparison.OrdinalIgnoreCase)) {
                int test = TestOrApply(device, width, height, hz, CDS_TEST);
                if (test != 0) return EmitResult(test);
                return EmitResult(TestOrApply(device, width, height, hz, 0));
            }
            if (op.Equals("apply-persist", StringComparison.OrdinalIgnoreCase)) {
                int test = TestOrApply(device, width, height, hz, CDS_TEST);
                if (test != 0) return EmitResult(test);
                return EmitResult(TestOrApply(device, width, height, hz, CDS_UPDATEREGISTRY));
            }
            Console.Error.WriteLine("Unknown operation: " + op);
            return 2;
        } catch (Exception ex) {
            Console.Error.WriteLine(ex.Message);
            return 1;
        }
    }
}
