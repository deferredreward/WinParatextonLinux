// Bare WinForms window reporting clicks and motion it actually receives, on whichever
// monitor it is on. v2: handlers on BOTH the form and the fill label (v1 only listened on
// the form while the label covered it, so it could never see a click).
using System; using System.Drawing; using System.Windows.Forms;
class TinyWin : Form {
  int clicks = 0, moves = 0; Label lbl = new Label();
  TinyWin() { Text = "WINE CLICK TEST v2"; Width = 700; Height = 300; BackColor = Color.LightYellow;
    lbl.Dock = DockStyle.Fill; lbl.Font = new Font("Arial", 14); lbl.Text = "no clicks yet - click me"; Controls.Add(lbl);
    MouseEventHandler onDown = (s,e) => { clicks++; var scr = ((Control)s).PointToScreen(e.Location);
      string t = String.Format("CLICK {0} screen=({1},{2}) window={3} on={4}", clicks, scr.X, scr.Y, Bounds, Screen.FromControl(this).DeviceName);
      Console.WriteLine(t); lbl.Text = t + "\nmoves seen: " + moves; };
    MouseEventHandler onMove = (s,e) => { moves++; if (moves % 100 == 0) Console.WriteLine("MOVES {0} on={1}", moves, Screen.FromControl(this).DeviceName); };
    lbl.MouseDown += onDown; this.MouseDown += onDown; lbl.MouseMove += onMove; this.MouseMove += onMove;
    this.Move += (s,e) => Console.WriteLine("MOVE window={0} on={1}", Bounds, Screen.FromControl(this).DeviceName); }
  [STAThread] static void Main() { var f = new TinyWin(); var t = new Timer(); t.Interval = 150000; t.Tick += (s,e) => f.Close(); t.Start(); Application.Run(f);
    Console.WriteLine("total clicks {0} total moves {1}", f.clicks, f.moves); }
}
