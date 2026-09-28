using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

// Automates the ClickOnce maintenance dialog (dfshim.dll,ShArpMaintain).
// Kept at C# 5 syntax so that it compiles in Windows PowerShell 5.1 as well.
public static class CoDialog
{
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc p, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc p, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")] static extern int GetWindowLong(IntPtr h, int idx);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);

    // Language-independent: selects the 2nd radio button ("Remove the application") and clicks the default button (OK).
    // Returns false while the dialog (or its controls) is not available yet, so the caller can poll.
    public static bool RemoveApplication(uint pid)
    {
        IntPtr dlg = IntPtr.Zero;
        EnumWindows(delegate(IntPtr h, IntPtr l)
        {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p == pid && IsWindowVisible(h)) { dlg = h; return false; }
            return true;
        }, IntPtr.Zero);
        if (dlg == IntPtr.Zero) return false;

        List<IntPtr> radios = new List<IntPtr>();
        IntPtr ok = IntPtr.Zero;
        EnumChildWindows(dlg, delegate(IntPtr h, IntPtr l)
        {
            StringBuilder sb = new StringBuilder(64);
            GetClassName(h, sb, 64);
            if (sb.ToString() == "Button")
            {
                int type = GetWindowLong(h, -16) & 0xF;      // GWL_STYLE
                if (type == 4 || type == 9) radios.Add(h);   // BS_RADIOBUTTON / BS_AUTORADIOBUTTON
                else if (type == 1) ok = h;                  // BS_DEFPUSHBUTTON
            }
            return true;
        }, IntPtr.Zero);
        if (radios.Count < 2 || ok == IntPtr.Zero) return false;

        ShowWindow(dlg, 0);                                  // SW_HIDE
        SendMessage(radios[1], 0x00F5, IntPtr.Zero, IntPtr.Zero);  // BM_CLICK
        SendMessage(ok,        0x00F5, IntPtr.Zero, IntPtr.Zero);
        return true;
    }
}
