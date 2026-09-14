// A bare WinForms window that reports every left click it receives (client and
// screen coords, and which monitor Wine thinks it is on). Drag it to the second
// monitor and click inside it; compare with Wine's +event trace of X ButtonPress.
using System; using System.Drawing; using System.Windows.Forms;
class TinyWin : Form {
  int clicks = 0; Label lbl = new Label();
  TinyWin() { Text = "WINE CLICK TEST - drag me to the external, click inside 3x"; Width = 700; Height = 300; BackColor = Color.LightYellow;
    lbl.Dock = DockStyle.Fill; lbl.Font = new Font("Arial", 16); lbl.Text = "no clicks yet"; Controls.Add(lbl); }
  protected override void WndProc(ref Message m) {
    if (m.Msg == 0x201) { clicks++; int x = (short)((long)m.LParam & 0xFFFF), y = (short)(((long)m.LParam >> 16) & 0xFFFF); var scr = PointToScreen(new Point(x,y));
      string s = String.Format("CLICK {0} client=({1},{2}) screen=({3},{4}) window={5} on={6}", clicks, x, y, scr.X, scr.Y, Bounds, Screen.FromControl(this).DeviceName);
      Console.WriteLine(s); lbl.Text = s; }
    if (m.Msg == 0x3 /*WM_MOVE*/) Console.WriteLine("MOVE window={0} on={1}", Bounds, Screen.FromControl(this).DeviceName);
    base.WndProc(ref m); }
  [STAThread] static void Main() { var f = new TinyWin(); var t = new Timer(); t.Interval = 150000; t.Tick += (s,e) => f.Close(); t.Start(); Application.Run(f); Console.WriteLine("total clicks {0}", f.clicks); }
}
