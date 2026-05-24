using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text.Json;

internal static class Program
{
    private const int DwmwaExtendedFrameBounds = 9;

    private static int Main(string[] args)
    {
        try
        {
            Native.TrySetPerMonitorDpiAwareness();
            var options = Options.Parse(args);
            var process = FindProcess(options);
            var hwnd = process.MainWindowHandle;

            if (hwnd == IntPtr.Zero)
            {
                throw new InvalidOperationException($"Process {process.Id} has no main window handle.");
            }

            if (!Native.GetWindowRect(hwnd, out var windowRect))
            {
                throw new InvalidOperationException("GetWindowRect failed.");
            }

            var frameRect = TryGetExtendedFrameBounds(hwnd, out var dwmRect)
                ? dwmRect
                : windowRect;

            var captureRect = options.RectKind == RectKind.Window ? windowRect : frameRect;
            if (captureRect.Width <= 0 || captureRect.Height <= 0)
            {
                throw new InvalidOperationException($"Invalid capture rectangle: {captureRect}");
            }

            Directory.CreateDirectory(options.OutputDir);

            var timestamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
            var stem = $"{options.Prefix}-{timestamp}";
            var pngPath = Path.Combine(options.OutputDir, $"{stem}.png");
            var jsonPath = Path.Combine(options.OutputDir, $"{stem}.json");

            using (var bitmap = new Bitmap(captureRect.Width, captureRect.Height, PixelFormat.Format32bppRgb))
            using (var graphics = Graphics.FromImage(bitmap))
            {
                graphics.CopyFromScreen(captureRect.Left, captureRect.Top, 0, 0, captureRect.Size, CopyPixelOperation.SourceCopy);
                bitmap.Save(pngPath, ImageFormat.Png);
            }

            var metadata = new CaptureMetadata
            {
                Png = pngPath,
                ProcessId = process.Id,
                ProcessName = process.ProcessName,
                Title = process.MainWindowTitle,
                Hwnd = $"0x{hwnd.ToInt64():X}",
                RectUsed = options.RectKind.ToString().ToLowerInvariant(),
                WindowRect = RectMetadata.From(windowRect),
                ExtendedFrameBounds = RectMetadata.From(frameRect),
                CaptureRect = RectMetadata.From(captureRect),
                CapturedAt = DateTimeOffset.Now,
            };

            File.WriteAllText(
                jsonPath,
                JsonSerializer.Serialize(metadata, new JsonSerializerOptions { WriteIndented = true }));

            Console.WriteLine(pngPath);
            Console.WriteLine(jsonPath);
            Console.WriteLine($"hwnd={metadata.Hwnd}");
            Console.WriteLine($"window={windowRect}");
            Console.WriteLine($"frame={frameRect}");
            Console.WriteLine($"captured={captureRect}");
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex.Message);
            return 1;
        }
    }

    private static Process FindProcess(Options options)
    {
        if (options.ProcessId is int pid)
        {
            var proc = Process.GetProcessById(pid);
            proc.Refresh();
            return proc;
        }

        var processes = Process.GetProcessesByName(options.ProcessName)
            .Where(p => p.MainWindowHandle != IntPtr.Zero)
            .OrderByDescending(GetStartTimeSafe)
            .ToArray();

        if (processes.Length == 0)
        {
            throw new InvalidOperationException($"No process named '{options.ProcessName}' with a main window was found.");
        }

        return processes[0];
    }

    private static DateTime GetStartTimeSafe(Process process)
    {
        try
        {
            return process.StartTime;
        }
        catch
        {
            return DateTime.MinValue;
        }
    }

    private static bool TryGetExtendedFrameBounds(IntPtr hwnd, out Rect rect)
    {
        var hr = Native.DwmGetWindowAttribute(hwnd, DwmwaExtendedFrameBounds, out rect, Marshal.SizeOf<Rect>());
        return hr == 0 && rect.Width > 0 && rect.Height > 0;
    }

    private enum RectKind
    {
        Frame,
        Window,
    }

    private sealed class Options
    {
        public string ProcessName { get; private init; } = "xemu";
        public int? ProcessId { get; private init; }
        public string OutputDir { get; private init; } =
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "run", "screenshots");
        public string Prefix { get; private init; } = "xemu";
        public RectKind RectKind { get; private init; } = RectKind.Frame;

        public static Options Parse(string[] args)
        {
            var options = new Options();

            for (var i = 0; i < args.Length; i++)
            {
                var arg = args[i];
                string Next()
                {
                    if (i + 1 >= args.Length)
                    {
                        throw new ArgumentException($"Missing value after {arg}");
                    }

                    return args[++i];
                }

                switch (arg)
                {
                    case "--process":
                        options = options.WithProcessName(Next());
                        break;
                    case "--pid":
                        options = options.WithProcessId(int.Parse(Next()));
                        break;
                    case "--out-dir":
                        options = options.WithOutputDir(Next());
                        break;
                    case "--prefix":
                        options = options.WithPrefix(Next());
                        break;
                    case "--rect":
                        options = options.WithRectKind(ParseRectKind(Next()));
                        break;
                    case "--help":
                    case "-h":
                        throw new ArgumentException(
                            "Usage: CaptureXemuWindow.exe [--process xemu] [--pid PID] [--out-dir DIR] [--prefix NAME] [--rect frame|window]");
                    default:
                        throw new ArgumentException($"Unknown argument: {arg}");
                }
            }

            return options;
        }

        private Options WithProcessName(string value) => new()
        {
            ProcessName = value,
            ProcessId = ProcessId,
            OutputDir = OutputDir,
            Prefix = Prefix,
            RectKind = RectKind,
        };

        private Options WithProcessId(int value) => new()
        {
            ProcessName = ProcessName,
            ProcessId = value,
            OutputDir = OutputDir,
            Prefix = Prefix,
            RectKind = RectKind,
        };

        private Options WithOutputDir(string value) => new()
        {
            ProcessName = ProcessName,
            ProcessId = ProcessId,
            OutputDir = value,
            Prefix = Prefix,
            RectKind = RectKind,
        };

        private Options WithPrefix(string value) => new()
        {
            ProcessName = ProcessName,
            ProcessId = ProcessId,
            OutputDir = OutputDir,
            Prefix = value,
            RectKind = RectKind,
        };

        private Options WithRectKind(RectKind value) => new()
        {
            ProcessName = ProcessName,
            ProcessId = ProcessId,
            OutputDir = OutputDir,
            Prefix = Prefix,
            RectKind = value,
        };

        private static RectKind ParseRectKind(string value) =>
            value.ToLowerInvariant() switch
            {
                "frame" => RectKind.Frame,
                "window" => RectKind.Window,
                _ => throw new ArgumentException("--rect must be 'frame' or 'window'."),
            };
    }

    private sealed class CaptureMetadata
    {
        public required string Png { get; init; }
        public int ProcessId { get; init; }
        public required string ProcessName { get; init; }
        public required string Title { get; init; }
        public required string Hwnd { get; init; }
        public required string RectUsed { get; init; }
        public required RectMetadata WindowRect { get; init; }
        public required RectMetadata ExtendedFrameBounds { get; init; }
        public required RectMetadata CaptureRect { get; init; }
        public DateTimeOffset CapturedAt { get; init; }
    }

    private sealed class RectMetadata
    {
        public int Left { get; init; }
        public int Top { get; init; }
        public int Right { get; init; }
        public int Bottom { get; init; }
        public int Width { get; init; }
        public int Height { get; init; }

        public static RectMetadata From(Rect rect) => new()
        {
            Left = rect.Left,
            Top = rect.Top,
            Right = rect.Right,
            Bottom = rect.Bottom,
            Width = rect.Width,
            Height = rect.Height,
        };
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Rect
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;

        public int Width => Right - Left;
        public int Height => Bottom - Top;
        public Size Size => new(Width, Height);

        public override string ToString() =>
            $"left={Left},top={Top},right={Right},bottom={Bottom},width={Width},height={Height}";
    }

    private static class Native
    {
        private static readonly IntPtr DpiAwarenessContextPerMonitorAwareV2 = new(-4);

        public static void TrySetPerMonitorDpiAwareness()
        {
            try
            {
                SetProcessDpiAwarenessContext(DpiAwarenessContextPerMonitorAwareV2);
            }
            catch
            {
                // Best effort only; older Windows builds can reject this.
            }
        }

        [DllImport("user32.dll")]
        private static extern bool SetProcessDpiAwarenessContext(IntPtr dpiContext);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);

        [DllImport("dwmapi.dll")]
        public static extern int DwmGetWindowAttribute(IntPtr hwnd, int attribute, out Rect rect, int attributeSize);
    }
}
