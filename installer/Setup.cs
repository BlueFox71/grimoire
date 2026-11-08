// Installateur et désinstallateur de Grimoire pour Windows (C# 5, compilé par installer\build.ps1 avec le csc de
// Windows). Modèle : l'installateur de Disney Music.
//
// Le build Flutter (dossier Release + version.txt) est une archive zip ajoutée à la fin de l'exe, suivie de sa position
// (8 octets) et d'une signature (8 octets). Pas d'assistant : lancé par Le Grenier ou à la main, l'exe installe ou met à
// jour Grimoire dans %LOCALAPPDATA%\Programs\Grimoire si la version installée diffère, puis l'ouvre.
// Sans archive, ou avec /uninstall, l'exe sert de désinstallateur.
//
// Les livres, notes et commentaires vivent dans les données de l'appli (%APPDATA%), jamais dans ce dossier : ni la mise à
// jour ni la désinstallation n'y touchent.
//
// Arguments : /dir <dossier> (autre dossier, pour les essais : ni raccourci ni inscription dans Windows),
//             /nolaunch (n'ouvre pas l'appli), /uninstall.
using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("Grimoire")]
[assembly: AssemblyProduct("Grimoire")]

static class Setup
{
    public const string AppName = "Grimoire";
    public const string ExeName = "Grimoire.exe";
    const string Magic = "GRIMOIR1";
    const string UninstallKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\Grimoire";

    [STAThread]
    static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        string self = Assembly.GetExecutingAssembly().Location;
        try
        {
            if (args.Length >= 2 && args[0] == "/uninstall-from") return Uninstall(args[1]);
            long offset = PayloadOffset(self);
            if (offset < 0 || HasArg(args, "/uninstall"))
            {
                // Le désinstallateur se copie hors du dossier pour pouvoir le supprimer en entier
                string dir = Path.GetDirectoryName(self);
                string temp = Path.Combine(Path.GetTempPath(), "Grimoire-desinstallation.exe");
                File.Copy(self, temp, true);
                Process.Start(temp, "/uninstall-from \"" + dir + "\"");
                return 0;
            }
            string custom = ArgValue(args, "/dir");
            string target = custom != null ? Path.GetFullPath(custom) : DefaultDir();
            return InstallForm.Run(self, offset, target, custom == null, !HasArg(args, "/nolaunch"));
        }
        catch (Exception e)
        {
            MessageBox.Show(e.Message, AppName, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    static bool HasArg(string[] args, string name)
    {
        foreach (var a in args) if (string.Equals(a, name, StringComparison.OrdinalIgnoreCase)) return true;
        return false;
    }

    static string ArgValue(string[] args, string name)
    {
        for (int i = 0; i < args.Length - 1; i++)
            if (string.Equals(args[i], name, StringComparison.OrdinalIgnoreCase)) return args[i + 1];
        return null;
    }

    static long PayloadOffset(string exe)
    {
        using (var f = File.OpenRead(exe))
        {
            if (f.Length < 16) return -1;
            f.Seek(-16, SeekOrigin.End);
            var buf = new byte[16];
            f.Read(buf, 0, 16);
            if (Encoding.ASCII.GetString(buf, 8, 8) != Magic) return -1;
            return BitConverter.ToInt64(buf, 0);
        }
    }

    public static string DefaultDir()
    {
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Grimoire");
    }

    public static string MenuLink() { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), AppName + ".lnk"); }

    // Version installée dans le dossier, ou "" si l'installation est absente ou incomplète (version.txt est écrit en
    // dernier : une installation interrompue n'en a pas, et sera refaite au lancement suivant)
    public static string InstalledVersion(string dir)
    {
        string file = Path.Combine(dir, "version.txt");
        if (!File.Exists(file) || !File.Exists(Path.Combine(dir, ExeName))) return "";
        return File.ReadAllText(file).Trim();
    }

    // Arrête un Grimoire lancé depuis ce dossier, pour pouvoir remplacer ou supprimer ses fichiers. On lui demande
    // d'abord de se fermer (il termine ainsi d'enregistrer ses modifications), et on ne force qu'ensuite.
    public static void StopRunning(string dir)
    {
        string exe = Path.Combine(dir, ExeName);
        foreach (var p in Process.GetProcessesByName(Path.GetFileNameWithoutExtension(ExeName)))
        {
            try
            {
                if (!string.Equals(p.MainModule.FileName, exe, StringComparison.OrdinalIgnoreCase)) continue;
                if (p.CloseMainWindow() && p.WaitForExit(4000)) continue;
                p.Kill();
                p.WaitForExit(5000);
            }
            catch { }
        }
    }

    public static void Launch(string dir)
    {
        Process.Start(new ProcessStartInfo(Path.Combine(dir, ExeName)) { WorkingDirectory = dir, UseShellExecute = false });
    }

    public static void CreateLink(string path, string dir)
    {
        Type shellType = Type.GetTypeFromProgID("WScript.Shell");
        object shell = Activator.CreateInstance(shellType);
        object link = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { path });
        Type t = link.GetType();
        t.InvokeMember("TargetPath", BindingFlags.SetProperty, null, link, new object[] { Path.Combine(dir, ExeName) });
        t.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, link, new object[] { dir });
        t.InvokeMember("Description", BindingFlags.SetProperty, null, link, new object[] { "Ta pile à lire, filtrée selon l'envie du moment" });
        t.InvokeMember("Save", BindingFlags.InvokeMethod, null, link, null);
    }

    public static void Register(string dir, string version, long sizeKb)
    {
        using (var k = Registry.CurrentUser.CreateSubKey(UninstallKey))
        {
            k.SetValue("DisplayName", AppName);
            k.SetValue("DisplayVersion", version);
            k.SetValue("Publisher", AppName);
            k.SetValue("InstallLocation", dir);
            k.SetValue("DisplayIcon", Path.Combine(dir, ExeName));
            k.SetValue("UninstallString", "\"" + Path.Combine(dir, "Desinstaller.exe") + "\" /uninstall");
            k.SetValue("EstimatedSize", (int)Math.Min(sizeKb, int.MaxValue), RegistryValueKind.DWord);
            k.SetValue("NoModify", 1, RegistryValueKind.DWord);
            k.SetValue("NoRepair", 1, RegistryValueKind.DWord);
        }
    }

    static int Uninstall(string dir)
    {
        if (!File.Exists(Path.Combine(dir, ExeName)))
        {
            MessageBox.Show("Aucune installation de Grimoire trouvée dans " + dir + ".", AppName);
            return 1;
        }
        if (MessageBox.Show("Désinstaller Grimoire de cet ordinateur ?\n\nTes livres, notes et commentaires restent sur l'ordinateur.",
                AppName, MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return 0;
        Thread.Sleep(1000); // laisse le désinstallateur d'origine se fermer
        StopRunning(dir);
        try { File.Delete(MenuLink()); } catch { }
        Registry.CurrentUser.DeleteSubKeyTree(UninstallKey, false);
        try { Directory.Delete(dir, true); } catch { }
        MessageBox.Show("Grimoire a été désinstallé.", AppName, MessageBoxButtons.OK, MessageBoxIcon.Information);
        return 0;
    }
}

// Lecture de l'archive à partir de sa position dans l'exe
class SliceStream : Stream
{
    readonly Stream inner; readonly long start; readonly long length;
    public SliceStream(Stream inner, long start, long length) { this.inner = inner; this.start = start; this.length = length; inner.Position = start; }
    public override bool CanRead { get { return true; } }
    public override bool CanSeek { get { return true; } }
    public override bool CanWrite { get { return false; } }
    public override long Length { get { return length; } }
    public override long Position { get { return inner.Position - start; } set { inner.Position = start + value; } }
    public override int Read(byte[] buffer, int offset, int count)
    {
        long left = length - Position;
        if (left <= 0) return 0;
        return inner.Read(buffer, offset, (int)Math.Min(count, left));
    }
    public override long Seek(long offset, SeekOrigin origin)
    {
        long target = origin == SeekOrigin.Begin ? offset : origin == SeekOrigin.Current ? Position + offset : length + offset;
        Position = target;
        return target;
    }
    public override void Flush() { }
    public override void SetLength(long value) { throw new NotSupportedException(); }
    public override void Write(byte[] buffer, int offset, int count) { throw new NotSupportedException(); }
    protected override void Dispose(bool disposing) { if (disposing) inner.Dispose(); base.Dispose(disposing); }
}

// Petite fenêtre de progression, affichée seulement quand il y a quelque chose à installer
class InstallForm : Form
{
    readonly string exe; readonly long offset;
    readonly ProgressBar progress = new ProgressBar();
    readonly Label status = new Label();
    string version = "";

    InstallForm(string exe, long offset)
    {
        this.exe = exe; this.offset = offset;
        using (var zip = OpenPayload())
        {
            var e = zip.GetEntry("version.txt");
            if (e == null) throw new InvalidDataException("archive sans version.txt");
            using (var r = new StreamReader(e.Open())) version = r.ReadToEnd().Trim();
        }

        Text = Setup.AppName + " " + version;
        Font = new Font("Segoe UI", 9.75f);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false; MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(480, 170);
        BackColor = Color.FromArgb(0x1b, 0x16, 0x26);
        ForeColor = Color.White;
        try { Icon = Icon.ExtractAssociatedIcon(exe); } catch { }

        var title = new Label { Text = Setup.AppName, Font = new Font("Segoe UI Semibold", 20f), AutoSize = true, Location = new Point(24, 18) };
        progress.SetBounds(26, 84, 428, 16);
        status.SetBounds(26, 110, 428, 40);
        status.ForeColor = Color.FromArgb(0xe8, 0xc7, 0x7a);
        status.Text = "Préparation de Grimoire sur cet ordinateur…";
        Controls.AddRange(new Control[] { title, progress, status });
    }

    public static int Run(string exe, long offset, string dir, bool integrate, bool launch)
    {
        var form = new InstallForm(exe, offset);
        // Un seul installateur à la fois (double clic sur « Ouvrir », menu Démarrer + Grenier…) : le second attend que
        // le premier ait fini, puis revérifie la version — il n'a alors plus rien à faire.
        using (var mutex = new Mutex(false, @"Local\GrimoireSetup"))
        {
            try { mutex.WaitOne(); } catch (AbandonedMutexException) { }
            try
            {
                if (!form.InstallIfNeeded(dir, integrate)) return 1;
            }
            finally { mutex.ReleaseMutex(); }
        }
        if (launch) Setup.Launch(dir);
        return 0;
    }

    bool InstallIfNeeded(string dir, bool integrate)
    {
        var form = this;
        if (Setup.InstalledVersion(dir) != form.version)
        {
            bool installed = false, working = true;
            // Une installation interrompue laisserait un dossier incomplet
            form.FormClosing += (s, e) => { if (working && e.CloseReason == CloseReason.UserClosing) e.Cancel = true; };
            form.Shown += delegate
            {
                var worker = new Thread(() =>
                {
                    try
                    {
                        form.Install(dir, integrate);
                        installed = true;
                    }
                    catch (Exception e)
                    {
                        form.Invoke((Action)(() => MessageBox.Show(form, "Impossible d'installer Grimoire : " + e.Message, Setup.AppName, MessageBoxButtons.OK, MessageBoxIcon.Error)));
                    }
                    form.BeginInvoke((Action)(() => { working = false; form.Close(); }));
                });
                worker.IsBackground = true;
                worker.Start();
            };
            Application.Run(form);
            return installed;
        }
        return true;
    }

    ZipArchive OpenPayload()
    {
        var f = new FileStream(exe, FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 20);
        return new ZipArchive(new SliceStream(f, offset, f.Length - 16 - offset), ZipArchiveMode.Read);
    }

    void SetStatus(string text) { BeginInvoke((Action)(() => status.Text = text)); }
    void SetProgress(int pct) { BeginInvoke((Action)(() => progress.Value = Math.Max(0, Math.Min(pct, 100)))); }

    void Install(string dir, bool integrate)
    {
        // On ne vide qu'un dossier qui est déjà celui de Grimoire (ou vide) : un /dir mal choisi ne doit rien effacer.
        // Le dossier par défaut (Programs\Grimoire) appartient à l'appli : il est toujours accepté, pour qu'une mise
        // à jour interrompue au milieu (exe déjà supprimé) se répare au lancement suivant au lieu de bloquer.
        // Desinstaller.exe, supprimé en dernier, signe aussi un dossier de Grimoire.
        if (!integrate && Directory.Exists(dir) && Directory.GetFileSystemEntries(dir).Length > 0
            && !File.Exists(Path.Combine(dir, Setup.ExeName)) && !File.Exists(Path.Combine(dir, "Desinstaller.exe")))
            throw new IOException(dir + " n'est pas vide et ne contient pas Grimoire.");

        SetStatus("Fermeture de Grimoire s'il est ouvert…");
        Setup.StopRunning(dir);
        // Les fichiers sont remplacés en entier, pour ne pas garder de fichiers d'une ancienne version. version.txt part
        // en premier (l'installation n'est plus considérée comme complète), l'exe et le désinstallateur en dernier
        // (le dossier reste reconnaissable si on s'arrête en route).
        if (Directory.Exists(dir))
        {
            string[] first = { "version.txt" }, last = { Setup.ExeName, "Desinstaller.exe" };
            foreach (var name in first) File.Delete(Path.Combine(dir, name));
            foreach (var entry in Directory.GetFileSystemEntries(dir))
            {
                if (Array.IndexOf(last, Path.GetFileName(entry)) >= 0) continue;
                if (Directory.Exists(entry)) Directory.Delete(entry, true); else File.Delete(entry);
            }
            foreach (var name in last) File.Delete(Path.Combine(dir, name));
        }
        Directory.CreateDirectory(dir);

        string root = Path.GetFullPath(dir).TrimEnd('\\') + "\\";
        long needed = 0, done = 0;
        using (var zip = OpenPayload())
        {
            foreach (var e in zip.Entries) needed += e.Length;
            var buffer = new byte[1 << 20];
            SetStatus("Installation de Grimoire " + version + "…");
            foreach (var entry in zip.Entries)
            {
                string name = entry.FullName.Replace('/', '\\');
                if (name.Equals("version.txt", StringComparison.OrdinalIgnoreCase)) continue; // écrit en dernier
                string target = Path.GetFullPath(Path.Combine(dir, name));
                if (!target.StartsWith(root, StringComparison.OrdinalIgnoreCase)) continue; // chemin hors du dossier : ignoré
                if (name.EndsWith("\\")) { Directory.CreateDirectory(target); continue; }
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                using (var input = entry.Open())
                using (var output = new FileStream(target, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20))
                {
                    int n;
                    while ((n = input.Read(buffer, 0, buffer.Length)) > 0)
                    {
                        output.Write(buffer, 0, n);
                        done += n;
                        SetProgress((int)(done * 100 / Math.Max(needed, 1)));
                    }
                }
            }
        }

        // Le désinstallateur est l'exe sans l'archive
        using (var input = File.OpenRead(exe))
        using (var output = File.Create(Path.Combine(dir, "Desinstaller.exe")))
        {
            var buf = new byte[1 << 16];
            long left = offset;
            int n;
            while (left > 0 && (n = input.Read(buf, 0, (int)Math.Min(buf.Length, left))) > 0) { output.Write(buf, 0, n); left -= n; }
        }
        if (integrate)
        {
            SetStatus("Raccourci du menu Démarrer…");
            Setup.CreateLink(Setup.MenuLink(), dir);
            Setup.Register(dir, version, needed / 1024);
        }
        File.WriteAllText(Path.Combine(dir, "version.txt"), version);
        SetProgress(100);
    }
}
