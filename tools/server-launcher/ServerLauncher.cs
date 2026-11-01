// ServerLauncher.cs
// A small window for starting and stopping the owner's two WoW servers (Scholomance Survival and
// Warband). They use different ports (Scholomance: auth 3725 / world 8086, Warband: 3724 / 8085),
// so both can run at once. Each "Play" button points the WoW client at its server first.
//
// "Cleanly" = the same as pressing Ctrl+C in the server's console window: the server saves every
// online player and closes its databases before exiting (worldserver Main.cpp, SignalHandler).
//
// Build: tools/server-launcher/build.ps1 (uses the C# compiler that ships with Windows).
// Also usable from a command line, e.g. for scripts:
//   ServerLauncher.exe --start warband      ServerLauncher.exe --stop scholomance
//   ServerLauncher.exe --status

using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

class Server
{
    public string Id, Name, RunFolder, RealmList;
    public Server(string id, string name, string runFolder, string realmList)
    { Id = id; Name = name; RunFolder = runFolder; RealmList = realmList; }
    public string Exe(string which) { return Path.Combine(RunFolder, which + ".exe"); }
}

static class Launcher
{
    // The servers this launcher knows about. Add a line here for a new server.
    public static readonly Server[] Servers =
    {
        new Server("scholomance", "Scholomance Survival", @"C:\Claude\Projects\azerothcore\build\bin\Release", "127.0.0.1:3725"),
        new Server("warband",     "Warband",              @"C:\Claude\Projects\azerothcore-warband\build\bin\Release", "127.0.0.1"),
    };
    public const string WowExe = @"C:\Claude\Downloads\ChromieCraft_3.3.5a\Wow.exe";

    // --- Finding running servers -------------------------------------------------------------

    // The running authserver/worldserver process that belongs to this server's run folder, if any.
    public static Process Find(Server s, string which)
    {
        string exe = s.Exe(which);
        foreach (Process p in Process.GetProcessesByName(which))
        {
            try
            {
                if (string.Equals(p.MainModule.FileName, exe, StringComparison.OrdinalIgnoreCase))
                    return p;
            }
            catch { } // a process we can't inspect isn't ours
        }
        return null;
    }

    public static bool IsRunning(Server s) { return Find(s, "worldserver") != null || Find(s, "authserver") != null; }

    // --- Starting ----------------------------------------------------------------------------

    // Each server gets its own console window, so GM commands can be typed into the worldserver.
    // The working folder must be the run folder: the configs load from "configs\" next to it.
    static void StartOne(Server s, string which)
    {
        var psi = new ProcessStartInfo(s.Exe(which))
        {
            WorkingDirectory = s.RunFolder,
            UseShellExecute = true,
        };
        Process.Start(psi);
    }

    public static void Start(Server s, Action<string> log)
    {
        if (Find(s, "authserver") == null) { log("Starting " + s.Name + " authserver..."); StartOne(s, "authserver"); Thread.Sleep(2000); }
        if (Find(s, "worldserver") == null) { log("Starting " + s.Name + " worldserver..."); StartOne(s, "worldserver"); }
        log(s.Name + " is starting. It's ready when its worldserver window shows the AC> prompt (about a minute).");
    }

    // --- Stopping ----------------------------------------------------------------------------

    [DllImport("kernel32.dll", SetLastError = true)] static extern bool AttachConsole(uint pid);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool FreeConsole();
    [DllImport("kernel32.dll")] static extern bool SetConsoleCtrlHandler(IntPtr handler, bool add);
    [DllImport("kernel32.dll")] static extern bool GenerateConsoleCtrlEvent(uint ctrlEvent, uint groupId);
    const uint CTRL_C_EVENT = 0;
    static readonly object consoleLock = new object();

    // Presses Ctrl+C in another process's console window, then waits for it to exit.
    // We briefly join that console; our own Ctrl+C handling is switched off meanwhile so the
    // launcher doesn't close itself.
    static bool SendCtrlC(Process p, int waitSeconds)
    {
        lock (consoleLock)
        {
            FreeConsole();
            if (!AttachConsole((uint)p.Id)) return false;
            SetConsoleCtrlHandler(IntPtr.Zero, true);
            GenerateConsoleCtrlEvent(CTRL_C_EVENT, 0);
            bool exited = p.WaitForExit(waitSeconds * 1000);
            FreeConsole();
            SetConsoleCtrlHandler(IntPtr.Zero, false);
            return exited;
        }
    }

    public static void Stop(Server s, Action<string> log)
    {
        Process world = Find(s, "worldserver");
        if (world != null)
        {
            log("Stopping " + s.Name + " worldserver (saving players)...");
            if (!SendCtrlC(world, 120))
            {
                log("The worldserver didn't stop by itself. Type  server shutdown 1  in its window, then try again.");
                return;
            }
        }
        Process auth = Find(s, "authserver");
        if (auth != null)
        {
            log("Stopping " + s.Name + " authserver...");
            if (!SendCtrlC(auth, 15)) { try { auth.Kill(); } catch { } } // auth holds no game data
        }
        log(s.Name + " stopped.");
    }

    public static Server ById(string id)
    {
        return Servers.FirstOrDefault(x => string.Equals(x.Id, id, StringComparison.OrdinalIgnoreCase));
    }

    // --- Entry point -------------------------------------------------------------------------

    [STAThread]
    static int Main(string[] args)
    {
        if (args.Length > 0) return CommandLine(args);
        Application.EnableVisualStyles();
        Application.Run(new LauncherForm());
        return 0;
    }

    static int CommandLine(string[] args)
    {
        // A windowed program has no console of its own; borrow the caller's for printing.
        AttachConsole(0xFFFFFFFF);
        Action<string> log = m => Console.WriteLine(m);
        string cmd = args[0].ToLowerInvariant();
        if (cmd == "--status")
        {
            foreach (Server s in Servers) log(s.Id + ": " + (IsRunning(s) ? "running" : "stopped"));
            return 0;
        }
        Server target = args.Length > 1 ? ById(args[1]) : null;
        if (target == null) { log("Usage: --start ID | --stop ID | --status   (IDs: " + string.Join(", ", Servers.Select(x => x.Id)) + ")"); return 2; }
        if (cmd == "--start") { Start(target, log); return 0; }
        if (cmd == "--stop") { Stop(target, log); return IsRunning(target) ? 1 : 0; }
        log("Unknown option " + args[0]);
        return 2;
    }
}

class LauncherForm : Form
{
    readonly Label[] status = new Label[Launcher.Servers.Length];
    readonly Button[] startButtons = new Button[Launcher.Servers.Length];
    readonly Button[] stopButtons = new Button[Launcher.Servers.Length];
    readonly TextBox logBox;
    bool busy;

    public LauncherForm()
    {
        Text = "WoW Server Launcher";
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        ClientSize = new Size(616, 300);
        Font = new Font("Segoe UI", 10f);
        StartPosition = FormStartPosition.CenterScreen;

        var note = new Label
        {
            Text = "Both servers can run at once. Play opens WoW on that server.",
            Location = new Point(16, 12), AutoSize = true, ForeColor = Color.DimGray,
        };
        Controls.Add(note);

        for (int i = 0; i < Launcher.Servers.Length; i++)
        {
            Server s = Launcher.Servers[i];
            int y = 44 + i * 56;
            Controls.Add(new Label { Text = s.Name, Location = new Point(16, y + 6), Size = new Size(170, 24), Font = new Font("Segoe UI", 11f, FontStyle.Bold) });
            status[i] = new Label { Location = new Point(190, y + 7), Size = new Size(90, 24) };
            Controls.Add(status[i]);
            startButtons[i] = new Button { Text = "Start", Location = new Point(290, y), Size = new Size(100, 36) };
            stopButtons[i] = new Button { Text = "Stop", Location = new Point(400, y), Size = new Size(100, 36) };
            startButtons[i].Click += (o, e) => Run(log => Launcher.Start(s, log));
            stopButtons[i].Click += (o, e) => Run(log => Launcher.Stop(s, log));
            Controls.Add(startButtons[i]);
            Controls.Add(stopButtons[i]);
            var play = new Button { Text = "Play", Location = new Point(510, y), Size = new Size(90, 36) };
            play.Click += (o, e) => Play(s);
            Controls.Add(play);
        }

        int bottom = 44 + Launcher.Servers.Length * 56;
        logBox = new TextBox
        {
            Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical,
            Location = new Point(16, bottom + 4), Size = new Size(584, ClientSize.Height - bottom - 16),
            BackColor = Color.White,
        };
        Controls.Add(logBox);

        var timer = new System.Windows.Forms.Timer { Interval = 2000 };
        timer.Tick += (o, e) => Refresh_();
        timer.Start();
        Refresh_();
    }

    // Points the WoW client at this server (its realmlist.wtf), then starts WoW.
    void Play(Server s)
    {
        try
        {
            string dir = Path.GetDirectoryName(Launcher.WowExe);
            File.WriteAllText(Path.Combine(dir, @"Data\enUS\realmlist.wtf"), "set realmlist " + s.RealmList + "\r\n");
            Process.Start(new ProcessStartInfo(Launcher.WowExe) { WorkingDirectory = dir });
            Log("WoW started on " + s.Name + ".");
        }
        catch (Exception ex) { Log("Couldn't start WoW: " + ex.Message); }
    }

    void Log(string message)
    {
        if (InvokeRequired) { BeginInvoke(new Action<string>(Log), message); return; }
        logBox.AppendText(DateTime.Now.ToString("HH:mm:ss") + "  " + message + Environment.NewLine);
    }

    // Runs a start/stop on a background thread so the window stays responsive while a server saves.
    void Run(Action<Action<string>> job)
    {
        if (busy) return;
        busy = true;
        Refresh_();
        new Thread(() =>
        {
            try { job(Log); }
            catch (Exception ex) { Log("Error: " + ex.Message); }
            busy = false;
            BeginInvoke(new Action(Refresh_));
        }) { IsBackground = true }.Start();
    }

    void Refresh_()
    {
        for (int i = 0; i < Launcher.Servers.Length; i++)
        {
            bool running = Launcher.IsRunning(Launcher.Servers[i]);
            status[i].Text = running ? "Running" : "Stopped";
            status[i].ForeColor = running ? Color.ForestGreen : Color.Gray;
            startButtons[i].Enabled = !busy && !running;
            stopButtons[i].Enabled = !busy && running;
        }
    }
}
