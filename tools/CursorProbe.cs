// Logs GetCursorPos (DPI-virtualized, what a DPI-unaware app sees) next to
// GetPhysicalCursorPos (raw) on every change, so the two can be compared while
// the pointer is on the secondary monitor.
using System; using System.Drawing; using System.Runtime.InteropServices; using System.Threading; using System.Windows.Forms;
static class CursorProbe {
  [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }
  [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] static extern bool GetPhysicalCursorPos(out POINT p);
  static int Main(string[] a) {
    int secs = a.Length > 0 ? int.Parse(a[0]) : 30;
    foreach (var s in Screen.AllScreens) Console.WriteLine("Screen {0} primary={1} bounds={2}", s.DeviceName, s.Primary, s.Bounds);
    var t0 = DateTime.Now; var end = t0.AddSeconds(secs); POINT ll = new POINT{X=int.MinValue}, lp = new POINT{X=int.MinValue}; DateTime lastPrint = DateTime.MinValue;
    while (DateTime.Now < end) {
      POINT l, p; GetCursorPos(out l); GetPhysicalCursorPos(out p);
      bool changed = l.X!=ll.X || l.Y!=ll.Y || p.X!=lp.X || p.Y!=lp.Y;
      if (changed && (DateTime.Now-lastPrint).TotalMilliseconds >= 250) {
        Console.WriteLine("t={0,5:F1}s logical=({1},{2}) physical=({3},{4}) screen={5}", (DateTime.Now-t0).TotalSeconds, l.X, l.Y, p.X, p.Y, Screen.FromPoint(new Point(l.X,l.Y)).DeviceName);
        ll=l; lp=p; lastPrint=DateTime.Now;
      }
      Thread.Sleep(40);
    }
    return 0;
  }
}
