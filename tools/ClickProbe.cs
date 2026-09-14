// Logs each left-button press with the position Wine reports (GetCursorPos, and the
// screen it falls on), plus a position sample every 2s, so a user clicking on a known
// monitor shows where Wine thinks that click happened.
using System; using System.Drawing; using System.Runtime.InteropServices; using System.Threading; using System.Windows.Forms;
static class ClickProbe {
  [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }
  [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
  static int Main(string[] a) {
    int secs = a.Length > 0 ? int.Parse(a[0]) : 60;
    foreach (var s in Screen.AllScreens) Console.WriteLine("Screen {0} primary={1} bounds={2}", s.DeviceName, s.Primary, s.Bounds);
    var t0 = DateTime.Now; var end = t0.AddSeconds(secs); bool wasDown=false; var lastSample=DateTime.MinValue; int clicks=0;
    while (DateTime.Now < end) {
      POINT p; GetCursorPos(out p); bool down = (GetAsyncKeyState(0x01) & 0x8000) != 0;
      string scr; try { scr = Screen.FromPoint(new Point(p.X,p.Y)).DeviceName; } catch { scr="?"; }
      if (down && !wasDown) { clicks++; Console.WriteLine("CLICK {0} t={1,5:F1}s at=({2},{3}) screen={4}", clicks, (DateTime.Now-t0).TotalSeconds, p.X, p.Y, scr); }
      wasDown = down;
      if ((DateTime.Now-lastSample).TotalSeconds >= 2) { Console.WriteLine("pos   t={0,5:F1}s at=({1},{2}) screen={3}", (DateTime.Now-t0).TotalSeconds, p.X, p.Y, scr); lastSample=DateTime.Now; }
      Thread.Sleep(15);
    }
    Console.WriteLine("clicks seen: {0}", clicks); return 0;
  }
}
