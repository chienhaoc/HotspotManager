// HotspotManager - native tray app for the Windows Mobile Hotspot (WinRT tethering API).
// Build with Build.bat (uses the .NET Framework csc.exe that ships with Windows).
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;
using Windows.Networking.Connectivity;
using Windows.Networking.NetworkOperators;

namespace HotspotManager
{
    class Client { public string Mac, Host, Ip, Duration; }

    class Status
    {
        public string State = "Off";
        public string Ssid = "", Pass = "", Source = "";
        public List<Client> Clients = new List<Client>();
    }

    static class Program
    {
        [STAThread]
        static void Main()
        {
            bool created;
            using (var mutex = new Mutex(true, @"Local\HotspotManager", out created))
            {
                if (!created) return;
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new TrayApp());
                GC.KeepAlive(mutex);
            }
        }
    }

    class TrayApp : ApplicationContext
    {
        // ---- colours / fonts -------------------------------------------------
        static readonly Color BG = Color.FromArgb(15, 23, 42), Card = Color.FromArgb(30, 41, 59);
        static readonly Color Green = Color.FromArgb(34, 197, 94), Red = Color.FromArgb(248, 113, 113);
        static readonly Color RedBtn = Color.FromArgb(239, 68, 68), Yellow = Color.FromArgb(251, 191, 36);
        static readonly Color TextC = Color.FromArgb(241, 245, 249), Sub = Color.FromArgb(148, 163, 184);
        static readonly Color Sep = Color.FromArgb(51, 65, 85), Grey = Color.FromArgb(107, 114, 128);

        const int FastMs = 2000, SlowMs = 5000;

        static readonly string[] SleepTargets = {
            "SERVICE \"SharedAccess\"", "SERVICE \"icssvc\"", "SERVICE \"WlanSvc\"",
            "DRIVER \"Microsoft Wi-Fi Direct Virtual Adapter\"",
            "DRIVER \"Microsoft Wi-Fi Direct Virtual Adapter #2\"", "DRIVER \"Legacy Kernel Caller\""
        };

        // ---- state -----------------------------------------------------------
        readonly Dictionary<string, DateTime> firstSeen = new Dictionary<string, DateTime>();
        readonly Dictionary<string, Icon> icons = new Dictionary<string, Icon>();
        readonly NotifyIcon tray = new NotifyIcon();
        readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
        readonly Control marshal = new Control();
        readonly string cfgFile = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"HotspotManager\config.ini");

        NetworkOperatorTetheringManager manager;
        Status last = new Status();
        bool autoResume = true, lastWanUp, isBusy, isRefreshing, isSleeping, wasRunningBeforeSleep, sleepSupport, exiting;
        int wanUpCount, wanDownCount;
        int cfgW = 390, cfgH = 520;
        int[] cfgCols = { 130, 100, 110, 80 };

        // menu
        ToolStripMenuItem miStart, miStop, miRepair, miSleep;

        // panel (created lazily, disposed on close)
        Form form;
        Label lblDot, lblState, lblClients, lblSrc, lblSsid, lblPass, lblSleep;
        Button btnToggle, btnRefresh, btnRepair;
        ListView list;

        public TrayApp()
        {
            LoadConfig();
            foreach (var s in new[] { "On", "Off", "Busy", "Waiting" }) icons[s] = MakeIcon(s);

            var h = marshal.Handle; // force handle creation so BeginInvoke works from other threads
            GC.KeepAlive(h);

            var menu = new ContextMenuStrip();
            var miOpen = (ToolStripMenuItem)menu.Items.Add("Open Panel");
            miOpen.Font = new Font("Segoe UI", 9, FontStyle.Bold);
            menu.Items.Add("-");
            miStart = (ToolStripMenuItem)menu.Items.Add("Start Hotspot");
            miStop = (ToolStripMenuItem)menu.Items.Add("Stop Hotspot");
            miRepair = (ToolStripMenuItem)menu.Items.Add("Repair Network (Fix No Internet)");
            menu.Items.Add("-");
            miSleep = (ToolStripMenuItem)menu.Items.Add("Allow PC Sleep");
            menu.Items.Add("-");
            var miExit = (ToolStripMenuItem)menu.Items.Add("Exit");

            miOpen.Click += delegate { ShowPanel(); };
            miStart.Click += async delegate { autoResume = true; await DoAction("Start", false); };
            miStop.Click += async delegate { autoResume = false; await DoAction("Stop", false); };
            miRepair.Click += async delegate { await Repair(); };
            miSleep.Click += async delegate { await ToggleSleep(); };
            miExit.Click += delegate { ExitApp(); };

            tray.Icon = icons["Off"];
            tray.Text = "Hotspot Manager";
            tray.ContextMenuStrip = menu;
            tray.DoubleClick += delegate { ShowPanel(); };
            tray.Visible = true;

            timer.Interval = SlowMs;
            timer.Tick += async delegate { await Tick(); };
            timer.Start();

            SystemEvents.PowerModeChanged += OnPower;

            sleepSupport = TestSleepSupport();
            var ignore = Tick();
        }

        // ---- helpers ---------------------------------------------------------
        static Icon MakeIcon(string state)
        {
            Color c = state == "On" ? Green : (state == "Busy" || state == "Waiting") ? Yellow : Grey;
            using (var bmp = new Bitmap(32, 32))
            {
                using (var g = Graphics.FromImage(bmp))
                using (var pen = new Pen(c, 2.5f))
                using (var br = new SolidBrush(c))
                {
                    g.SmoothingMode = SmoothingMode.AntiAlias;
                    g.Clear(Color.Transparent);
                    foreach (int r in new[] { 12, 8, 4 }) g.DrawArc(pen, 16 - r, 20 - r, r * 2, r * 2, 210, 120);
                    g.FillEllipse(br, 14, 18, 4, 4);
                }
                return Icon.FromHandle(bmp.GetHicon()); // 4 handles for the whole process lifetime
            }
        }

        static async Task<T> Aw<T>(Windows.Foundation.IAsyncOperation<T> op, int seconds)
        {
            // No Windows.winmd (SDK) here, so bridge IAsyncOperation to Task by hand.
            var tcs = new TaskCompletionSource<T>();
            op.Completed = new Windows.Foundation.AsyncOperationCompletedHandler<T>(delegate (Windows.Foundation.IAsyncOperation<T> o, Windows.Foundation.AsyncStatus st)
            {
                if (st == Windows.Foundation.AsyncStatus.Completed) tcs.TrySetResult(o.GetResults());
                else tcs.TrySetException(new InvalidOperationException("Hotspot operation " + st));
            });
            var t = tcs.Task;
            if (await Task.WhenAny(t, Task.Delay(seconds * 1000)) != t)
                throw new TimeoutException("Windows Mobile Hotspot operation timed out after " + seconds + " seconds.");
            return await t;
        }

        static ConnectionProfile GetProfile()
        {
            try { return NetworkInformation.GetInternetConnectionProfile(); } catch { return null; }
        }

        static bool IsWanUp(ConnectionProfile p)
        {
            try { return p != null && p.GetNetworkConnectivityLevel() == NetworkConnectivityLevel.InternetAccess; }
            catch { return false; }
        }

        NetworkOperatorTetheringManager FindManager(ConnectionProfile p)
        {
            if (p != null)
            {
                try { manager = NetworkOperatorTetheringManager.CreateFromConnectionProfile(p); } catch { }
            }
            if (manager != null) return manager;
            try
            {
                foreach (var cp in NetworkInformation.GetConnectionProfiles())
                {
                    try
                    {
                        var m = NetworkOperatorTetheringManager.CreateFromConnectionProfile(cp);
                        if (m.TetheringOperationalState != TetheringOperationalState.Off) { manager = m; break; }
                    }
                    catch { }
                }
            }
            catch { }
            return manager;
        }

        static string FormatDuration(TimeSpan d)
        {
            if (d.TotalHours >= 1) return string.Format("{0:D2}h {1:D2}m", (int)d.TotalHours, d.Minutes);
            if (d.TotalMinutes >= 1) return string.Format("{0:D2}m {1:D2}s", (int)d.TotalMinutes, d.Seconds);
            return string.Format("{0:D2}s", (int)d.TotalSeconds);
        }

        Status GetStatus(ConnectionProfile p)
        {
            var s = new Status();
            try
            {
                var mgr = FindManager(p);
                if (mgr == null)
                {
                    s.Source = autoResume ? "Disconnected (Auto-start on WAN UP)" : "No internet connection";
                    return s;
                }
                var cfg = mgr.GetCurrentAccessPointConfiguration();
                s.State = mgr.TetheringOperationalState.ToString();
                if (s.State != "On") firstSeen.Clear();

                var now = DateTime.Now;
                var seen = new HashSet<string>();
                foreach (var c in mgr.GetTetheringClients())
                {
                    string mac = c.MacAddress;
                    seen.Add(mac);
                    if (!firstSeen.ContainsKey(mac)) firstSeen[mac] = now;
                    string host = "Unknown", ip = "";
                    foreach (var hn in c.HostNames)
                    {
                        if (hn.Type == Windows.Networking.HostNameType.Ipv4 && ip.Length == 0) ip = hn.CanonicalName;
                        else if (hn.Type == Windows.Networking.HostNameType.DomainName && host == "Unknown") host = hn.CanonicalName;
                    }
                    s.Clients.Add(new Client { Mac = mac, Host = host, Ip = ip, Duration = FormatDuration(now - firstSeen[mac]) });
                }
                var gone = new List<string>();
                foreach (var k in firstSeen.Keys) if (!seen.Contains(k)) gone.Add(k);
                foreach (var k in gone) firstSeen.Remove(k);

                s.Ssid = cfg.Ssid;
                s.Pass = cfg.Passphrase;
                s.Source = p != null ? p.ProfileName : "WAN Disconnected";
            }
            catch (Exception ex) { s = new Status { State = "Error", Source = ex.Message }; }
            return s;
        }

        async Task<bool> WaitState(NetworkOperatorTetheringManager m, TetheringOperationalState expected, int seconds)
        {
            var sw = Stopwatch.StartNew();
            while (sw.Elapsed.TotalSeconds < seconds)
            {
                try { if (m.TetheringOperationalState == expected) return true; } catch { }
                await Task.Delay(250);
            }
            return false;
        }

        async Task<string> InvokeAction(string action)
        {
            try
            {
                var p = GetProfile();
                if (action == "Start")
                {
                    if (p == null) return "No active internet connection profile found.";
                    manager = NetworkOperatorTetheringManager.CreateFromConnectionProfile(p);
                    var res = await Aw(manager.StartTetheringAsync(), 30);
                    if (res.Status != TetheringOperationStatus.Success)
                        return "Failed to start hotspot: Status = " + res.Status + ", Error = " + res.AdditionalErrorMessage;
                    if (!await WaitState(manager, TetheringOperationalState.On, 15))
                        return "Hotspot start timed out while Windows remained in transition. Use Repair Network manually.";
                }
                else
                {
                    var mgr = FindManager(p);
                    if (mgr != null)
                    {
                        var res = await Aw(mgr.StopTetheringAsync(), 30);
                        if (res.Status != TetheringOperationStatus.Success)
                            return "Failed to stop hotspot: Status = " + res.Status + ", Error = " + res.AdditionalErrorMessage;
                        if (!await WaitState(mgr, TetheringOperationalState.Off, 15))
                            return "Hotspot stop timed out while Windows remained in transition. Use Repair Network manually.";
                    }
                }
                return null;
            }
            catch (Exception ex) { return "Error executing " + action + ": " + ex.Message; }
        }

        // ---- external commands ----------------------------------------------
        static Task<string> RunHidden(string exe, string args)
        {
            return Task.Run(delegate
            {
                try
                {
                    var psi = new ProcessStartInfo(exe, args)
                    {
                        UseShellExecute = false, CreateNoWindow = true,
                        RedirectStandardOutput = true, StandardOutputEncoding = Encoding.Default
                    };
                    using (var pr = Process.Start(psi))
                    {
                        string o = pr.StandardOutput.ReadToEnd();
                        pr.WaitForExit(15000);
                        return o;
                    }
                }
                catch { return ""; }
            });
        }

        static Task<int> RunElevated(IEnumerable<string> lines)
        {
            return Task.Run(delegate
            {
                string bat = Path.Combine(Path.GetTempPath(), "hotspotmgr_" + Guid.NewGuid().ToString("N") + ".cmd");
                try
                {
                    File.WriteAllText(bat, "@echo off\r\n" + string.Join("\r\n", new List<string>(lines).ToArray()) + "\r\n", Encoding.Default);
                    var psi = new ProcessStartInfo("cmd.exe", "/c \"" + bat + "\"")
                    {
                        UseShellExecute = true, Verb = "runas", WindowStyle = ProcessWindowStyle.Hidden
                    };
                    using (var pr = Process.Start(psi)) { pr.WaitForExit(60000); return pr.ExitCode; }
                }
                finally { try { File.Delete(bat); } catch { } }
            });
        }

        async Task FlushCaches()
        {
            await Task.WhenAll(RunHidden("ipconfig.exe", "/flushdns"), RunHidden("netsh.exe", "interface ip delete arpcache"));
        }

        static bool TestSleepSupport()
        {
            try
            {
                var psi = new ProcessStartInfo("powercfg.exe", "/requestsoverride")
                { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true };
                using (var pr = Process.Start(psi))
                {
                    string o = pr.StandardOutput.ReadToEnd();
                    pr.WaitForExit(5000);
                    return o.Contains("SharedAccess");
                }
            }
            catch { return false; }
        }

        async Task ToggleSleep()
        {
            bool enable = !TestSleepSupport();
            var lines = new List<string>();
            foreach (var t in SleepTargets)
                lines.Add("powercfg /requestsoverride " + t + (enable ? " System Awaymode" : ""));
            try { await RunElevated(lines); } catch (Win32Exception) { }
            sleepSupport = TestSleepSupport();
            Render();
        }

        // ---- refresh / actions ----------------------------------------------
        async Task Tick()
        {
            if (isSleeping || isBusy || isRefreshing || exiting) return;
            isRefreshing = true;
            try { await Refresh(); }
            catch { }
            finally { isRefreshing = false; }
        }

        async Task Refresh()
        {
            var p = GetProfile();
            bool wan = IsWanUp(p);
            lastWanUp = wan;
            if (wan) { wanUpCount++; wanDownCount = 0; } else { wanDownCount++; wanUpCount = 0; }

            var cur = GetStatus(p);
            if (!wan)
            {
                if (cur.State == "On" && wanDownCount >= 2 && !isBusy) { await DoAction("Stop", true); return; }
            }
            else if (wanUpCount >= 2 && autoResume && !isBusy)
            {
                if (cur.State != "On" && cur.State != "InTransition") { await DoAction("Start", true); return; }
            }
            last = cur;
            Render();
        }

        void SetBusy(string text)
        {
            tray.Icon = icons["Busy"];
            tray.Text = "Hotspot: " + text;
            if (form != null && form.Visible)
            {
                lblState.Text = text; lblState.ForeColor = Yellow; lblDot.ForeColor = Yellow;
                btnToggle.Text = text; btnToggle.BackColor = Yellow;
                btnToggle.Enabled = false; btnRepair.Enabled = false;
            }
        }

        async Task DoAction(string action, bool auto)
        {
            if (isBusy) return;
            isBusy = true;
            try
            {
                SetBusy(action == "Start" ? "Starting..." : "Stopping...");
                if (action == "Start") await FlushCaches();
                string err = await InvokeAction(action);
                if (err != null && !auto)
                    MessageBox.Show(err, "Hotspot Manager Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                if (action == "Start") autoResume = true;
                else if (!auto) autoResume = false;
                last = GetStatus(GetProfile());
            }
            finally { isBusy = false; }
            Render();
        }

        async Task Repair()
        {
            if (isBusy) return;
            isBusy = true;
            try
            {
                SetBusy("Repairing...");
                await FlushCaches();
                string stopErr = await InvokeAction("Stop");

                // Resetting WLAN AutoConfig interrupts every Wi-Fi connection, so it is manual-only and needs elevation.
                int code;
                try { code = await RunElevated(new[] { "net stop WlanSvc /y", "net start WlanSvc", "timeout /t 2 /nobreak >nul" }); }
                catch (Exception ex)
                {
                    MessageBox.Show("Unable to reset WLAN AutoConfig. Repair was cancelled." +
                        (stopErr != null ? "\nStop result: " + stopErr : "") + "\n" + ex.Message,
                        "Hotspot Manager Repair", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }
                await FlushCaches();

                if (IsWanUp(GetProfile()))
                {
                    string startErr = await InvokeAction("Start");
                    if (startErr != null)
                        MessageBox.Show(startErr, "Hotspot Manager Repair", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
                else
                    MessageBox.Show("WLAN was reset, but no active internet connection is available. Reconnect iPhone USB and try again.",
                        "Hotspot Manager Repair", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                last = GetStatus(GetProfile());
            }
            finally { isBusy = false; }
            Render();
        }

        // ---- system events ---------------------------------------------------
        void OnPower(object sender, PowerModeChangedEventArgs e)
        {
            try
            {
                marshal.BeginInvoke(new Action(delegate
                {
                    if (e.Mode == PowerModes.Suspend)
                    {
                        isSleeping = true;
                        wasRunningBeforeSleep = last.State == "On";
                        if (wasRunningBeforeSleep && !isBusy) { var t = DoAction("Stop", true); }
                    }
                    else if (e.Mode == PowerModes.Resume)
                    {
                        isSleeping = false;
                        var t = Tick();
                    }
                }));
            }
            catch { }
        }

        // ---- tray / panel rendering -----------------------------------------
        void Render()
        {
            if (exiting) return;
            string state = last.State;
            int cnt = last.Clients.Count;
            string icon = state == "On" ? "On" : (autoResume && !lastWanUp) ? "Waiting" : "Off";
            tray.Icon = icons[icon];
            string txt = state == "On" ? "Hotspot: On" + (cnt > 0 ? " (" + cnt + " connected)" : "")
                : state == "InTransition" ? "Hotspot: Transitioning..."
                : icon == "Waiting" ? "Hotspot: Waiting for WAN..." : "Hotspot: Off";
            if (tray.Text != txt) tray.Text = txt;

            miStart.Enabled = state == "Off";
            miStop.Enabled = state == "On" || state == "InTransition";
            miRepair.Enabled = state != "Off" && lastWanUp;
            miSleep.Checked = sleepSupport;

            if (form == null || !form.Visible) return;

            bool waiting = state != "On" && autoResume && !lastWanUp;
            btnRepair.Enabled = state != "Off" && lastWanUp;
            btnToggle.Enabled = true;
            Color col; string stText, btnText; Color btnCol;
            if (state == "On") { col = Green; stText = "On"; btnText = "Stop Hotspot"; btnCol = RedBtn; }
            else if (state == "InTransition") { col = Yellow; stText = "Transitioning (use Repair if stuck)"; btnText = "Repair Network"; btnCol = Yellow; }
            else if (waiting) { col = Yellow; stText = "Off (Waiting for WAN)"; btnText = "Stop Auto-Resume"; btnCol = RedBtn; }
            else { col = Red; stText = "Off"; btnText = "Start Hotspot"; btnCol = Green; }
            lblDot.ForeColor = col; lblState.ForeColor = col; lblState.Text = stText;
            btnToggle.Text = btnText; btnToggle.BackColor = btnCol;

            lblClients.Text = "   " + cnt + " device" + (cnt != 1 ? "s" : "") + " connected";
            lblSrc.Text = last.Source.Length > 0 ? last.Source : "-";
            lblSsid.Text = last.Ssid.Length > 0 ? last.Ssid : "-";
            lblPass.Text = last.Pass.Length > 0 ? last.Pass : "-";
            lblSleep.Text = sleepSupport ? "Enabled (Sleep allowed)" : "Disabled (Click Tray Menu to enable)";
            lblSleep.ForeColor = sleepSupport ? Green : Sub;

            list.BeginUpdate();
            list.Items.Clear();
            if (cnt == 0) list.Items.Add(new ListViewItem("No devices connected") { ForeColor = Sub });
            else foreach (var c in last.Clients)
                    list.Items.Add(new ListViewItem(new[] { c.Host, c.Ip, c.Mac, c.Duration }));
            list.EndUpdate();
        }

        async void OnToggle()
        {
            if (isBusy) return;
            var p = GetProfile();
            lastWanUp = IsWanUp(p);
            string st = GetStatus(p).State;
            if (st == "InTransition") await Repair();
            else if (st == "On") { autoResume = false; await DoAction("Stop", false); }
            else if (autoResume && !lastWanUp) { autoResume = false; last = GetStatus(p); Render(); }
            else { autoResume = true; await DoAction("Start", false); }
        }

        // ---- panel -----------------------------------------------------------
        static Label L(string text, Font f, Color c, bool autoSize)
        {
            return new Label { Text = text, Font = f, ForeColor = c, BackColor = Color.Transparent, AutoSize = autoSize };
        }

        static Button B(string text, Font f, Color fore, Color back)
        {
            var b = new Button { Text = text, Font = f, ForeColor = fore, BackColor = back, FlatStyle = FlatStyle.Flat,
                Dock = DockStyle.Fill, Cursor = Cursors.Hand };
            b.FlatAppearance.BorderSize = 0;
            return b;
        }

        void ShowPanel()
        {
            sleepSupport = TestSleepSupport();
            if (form == null) BuildForm();
            form.Show();
            form.WindowState = FormWindowState.Normal;
            form.Activate();
            timer.Interval = FastMs;
            Render();
        }

        void BuildForm()
        {
            var fSmall = new Font("Segoe UI", 8);
            var fNorm = new Font("Segoe UI", 9);
            var fBold = new Font("Segoe UI", 10, FontStyle.Bold);

            form = new Form
            {
                Text = "Hotspot Manager", ClientSize = new Size(cfgW, cfgH), MinimumSize = new Size(320, 440),
                StartPosition = FormStartPosition.CenterScreen, MaximizeBox = false, BackColor = BG,
                ShowInTaskbar = false, AutoScaleMode = AutoScaleMode.Dpi, AutoScaleDimensions = new SizeF(96f, 96f)
            };

            var outer = new TableLayoutPanel { Dock = DockStyle.Fill, BackColor = BG, ColumnCount = 1, RowCount = 8, Padding = new Padding(14, 10, 14, 10) };
            foreach (int h in new[] { 56, 1, 140, 48, 24, 1, 20 }) outer.RowStyles.Add(new RowStyle(SizeType.Absolute, h));
            outer.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            form.Controls.Add(outer);

            // title
            var title = new Panel { Dock = DockStyle.Fill };
            var t1 = L("Hotspot Manager", new Font("Segoe UI", 13, FontStyle.Bold), TextC, true); t1.Location = new Point(0, 2);
            var t2 = L("Windows Mobile Hotspot Control Panel", fSmall, Sub, true); t2.Location = new Point(0, 36);
            title.Controls.Add(t1); title.Controls.Add(t2);
            outer.Controls.Add(title, 0, 0);
            outer.Controls.Add(new Panel { Dock = DockStyle.Fill, BackColor = Sep }, 0, 1);

            // status card
            var card = new Panel { Dock = DockStyle.Fill, BackColor = Card, Padding = new Padding(10, 8, 10, 6) };
            var flow = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, WrapContents = false, FlowDirection = FlowDirection.LeftToRight };
            lblDot = L("\u25CF", new Font("Segoe UI", 14), Red, true);
            lblState = L("Off", fBold, Red, true); lblState.Margin = new Padding(0, 6, 0, 0);
            lblClients = L("   0 devices connected", fSmall, Sub, true); lblClients.Margin = new Padding(6, 8, 0, 0);
            flow.Controls.Add(lblDot); flow.Controls.Add(lblState); flow.Controls.Add(lblClients);

            var grid = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 4 };
            grid.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            for (int i = 0; i < 4; i++) grid.RowStyles.Add(new RowStyle(SizeType.Percent, 25));
            string[] keys = { "Source", "SSID", "Password", "Sleep" };
            Label[] vals = new Label[4];
            for (int i = 0; i < 4; i++)
            {
                var k = L(keys[i] + "   ", fSmall, Sub, true); k.Anchor = AnchorStyles.Left;
                vals[i] = L("-", fNorm, TextC, true); vals[i].Anchor = AnchorStyles.Left;
                grid.Controls.Add(k, 0, i); grid.Controls.Add(vals[i], 1, i);
            }
            lblSrc = vals[0]; lblSsid = vals[1]; lblPass = vals[2]; lblSleep = vals[3];
            card.Controls.Add(grid); card.Controls.Add(flow);
            outer.Controls.Add(card, 0, 2);

            // buttons
            btnToggle = B("Start Hotspot", fBold, Color.White, Green);
            btnToggle.Margin = new Padding(0, 2, 0, 2);
            btnToggle.Click += delegate { OnToggle(); };
            outer.Controls.Add(btnToggle, 0, 3);

            var acts = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1 };
            acts.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            acts.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            btnRefresh = B("Refresh Status", fSmall, Sub, BG);
            btnRepair = B("Repair Network", fSmall, Sub, BG);
            foreach (var b in new[] { btnRefresh, btnRepair })
            {
                b.FlatAppearance.MouseOverBackColor = Card; b.FlatAppearance.MouseDownBackColor = Sep;
            }
            btnRefresh.Click += async delegate { await Tick(); };
            btnRepair.Click += async delegate { await Repair(); };
            acts.Controls.Add(btnRefresh, 0, 0); acts.Controls.Add(btnRepair, 1, 0);
            outer.Controls.Add(acts, 0, 4);
            outer.Controls.Add(new Panel { Dock = DockStyle.Fill, BackColor = Sep }, 0, 5);
            outer.Controls.Add(L("CONNECTED DEVICES", fSmall, Sub, false), 0, 6);

            list = new ListView
            {
                View = View.Details, FullRowSelect = true, BackColor = Card, ForeColor = TextC,
                Font = new Font("Consolas", 8.5f), BorderStyle = BorderStyle.None,
                HeaderStyle = ColumnHeaderStyle.Nonclickable, Dock = DockStyle.Fill
            };
            string[] cols = { "Hostname", "IP Address", "MAC Address", "Connected Time" };
            for (int i = 0; i < 4; i++) list.Columns.Add(cols[i], cfgCols[i]);
            outer.Controls.Add(list, 0, 7);

            form.FormClosing += delegate
            {
                SaveConfig();
                // The panel is rebuilt on demand: drop it (and its memory) while hidden in the tray.
            };
            form.FormClosed += delegate
            {
                timer.Interval = SlowMs;
                form = null;
                GC.Collect();
            };
        }

        // ---- config ----------------------------------------------------------
        void LoadConfig()
        {
            try
            {
                if (!File.Exists(cfgFile)) return;
                foreach (var line in File.ReadAllLines(cfgFile))
                {
                    var kv = line.Split(new[] { '=' }, 2);
                    int v;
                    if (kv.Length != 2 || !int.TryParse(kv[1], out v) || v <= 0) continue;
                    if (kv[0] == "Width" && v >= 320) cfgW = v;
                    else if (kv[0] == "Height" && v >= 400) cfgH = v;
                    else if (kv[0].StartsWith("Col")) { int i = kv[0][3] - '0'; if (i >= 0 && i < 4) cfgCols[i] = v; }
                }
            }
            catch { }
        }

        void SaveConfig()
        {
            try
            {
                if (form == null) return;
                cfgW = form.ClientSize.Width; cfgH = form.ClientSize.Height;
                for (int i = 0; i < 4; i++) cfgCols[i] = list.Columns[i].Width;
                Directory.CreateDirectory(Path.GetDirectoryName(cfgFile));
                File.WriteAllText(cfgFile, string.Format("Width={0}\r\nHeight={1}\r\nCol0={2}\r\nCol1={3}\r\nCol2={4}\r\nCol3={5}\r\n",
                    cfgW, cfgH, cfgCols[0], cfgCols[1], cfgCols[2], cfgCols[3]));
            }
            catch { }
        }

        // ---- exit ------------------------------------------------------------
        void ExitApp()
        {
            exiting = true;
            timer.Stop();
            SystemEvents.PowerModeChanged -= OnPower;
            if (form != null) { SaveConfig(); form.Close(); }
            tray.Visible = false;
            tray.Dispose();
            ExitThread();
        }
    }
}
