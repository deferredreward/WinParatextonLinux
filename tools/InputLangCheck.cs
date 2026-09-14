// Tiny probe for the Paratext "Culture is not supported ... 0 (0x0000)" crash.
// Reproduces exactly what System.Windows.Forms.InputLanguage.DefaultInputLanguage does,
// so you can prove a Wine runner is fixed before launching Paratext.
//
// Compile inside the bottle/prefix with the .NET Framework 4.8 compiler:
//   wine "C:\windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /r:System.Windows.Forms.dll /out:InputLangCheck.exe InputLangCheck.cs
// Run:
//   wine InputLangCheck.exe
// Expected on a fixed Wine (>= 11.2): "SPI_GETDEFAULTINPUTLANG ok=True hkl=0x4090409" and PASS.
// On a broken Wine: hkl=0x0 and FAIL with the same CultureNotFoundException Paratext shows.

using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

static class InputLangCheck
{
    [DllImport("user32.dll", SetLastError = true)]
    static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr[] pvParam, uint fWinIni);

    [DllImport("user32.dll")]
    static extern IntPtr GetKeyboardLayout(uint idThread);

    const uint SPI_GETDEFAULTINPUTLANG = 0x0059;

    static int Main()
    {
        var data = new IntPtr[1];
        bool ok = SystemParametersInfo(SPI_GETDEFAULTINPUTLANG, 0, data, 0);
        Console.WriteLine("SPI_GETDEFAULTINPUTLANG ok={0} hkl=0x{1:X}", ok, (long)data[0]);
        Console.WriteLine("GetKeyboardLayout(0) hkl=0x{0:X}", (long)GetKeyboardLayout(0));
        try
        {
            InputLanguage il = InputLanguage.DefaultInputLanguage;
            Console.WriteLine("DefaultInputLanguage handle=0x{0:X} culture={1} layout={2}",
                (long)il.Handle, il.Culture.Name, il.LayoutName);
            Console.WriteLine("PASS");
            return 0;
        }
        catch (Exception e)
        {
            Console.WriteLine("FAIL: {0}: {1}", e.GetType().Name, e.Message);
            return 1;
        }
    }
}
