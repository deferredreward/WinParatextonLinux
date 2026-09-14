// Prints what Wine reports to a .NET app about monitors, then samples the cursor
// position for N seconds so you can sweep the mouse across both monitors and see
// whether Wine's coordinates follow it or clamp at an edge.
using System; using System.Drawing; using System.Runtime.InteropServices; using System.Threading; using System.Windows.Forms;
static class ScreenProbe {
  [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }
  [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
  static int Main(string[] a) {
    int secs = a.Length > 0 ? int.Parse(a[0]) : 20;
    Console.WriteLine("SM_CMONITORS={0}  SM_XVIRTUALSCREEN={1} SM_YVIRTUALSCREEN={2} SM_CXVIRTUALSCREEN={3} SM_CYVIRTUALSCREEN={4}",
      GetSystemMetrics(80), GetSystemMetrics(76), GetSystemMetrics(77), GetSystemMetrics(78), GetSystemMetrics(79));
    Console.WriteLine("VirtualScreen={0}", SystemInformation.VirtualScreen);
    foreach (var s in Screen.AllScreens)
      Console.WriteLine("Screen {0} primary={1} bounds={2} working={3} bpp={4}", s.DeviceName, s.Primary, s.Bounds, s.WorkingArea, s.BitsPerPixel);
    Console.WriteLine("-- sampling cursor for {0}s (move the mouse across both monitors) --", secs);
    POINT last = new POINT { X = int.MinValue, Y = int.MinValue }; int minX=int.MaxValue,minY=int.MaxValue,maxX=int.MinValue,maxY=int.MinValue;
    var end = DateTime.Now.AddSeconds(secs);
    while (DateTime.Now < end) {
      POINT p; GetCursorPos(out p);
      if (p.X != last.X || p.Y != last.Y) { minX=Math.Min(minX,p.X); minY=Math.Min(minY,p.Y); maxX=Math.Max(maxX,p.X); maxY=Math.Max(maxY,p.Y); last = p; }
      Thread.Sleep(50);
    }
    Console.WriteLine("cursor range seen: X {0}..{1}  Y {2}..{3}", minX, maxX, minY, maxY);
    Console.WriteLine("screen containing last cursor pos ({0},{1}): {2}", last.X, last.Y, Screen.FromPoint(new Point(last.X,last.Y)).DeviceName);
    return 0;
  }
}
