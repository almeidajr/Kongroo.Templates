using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Kongroo.SampleApp.Worker;

/// <summary>Placeholder background service — replace with your own work loop.</summary>
public sealed class SampleWorker(ILogger<SampleWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // PeriodicTimer over Task.Delay: it does not drift. Cancellation of stoppingToken during
        // host shutdown is expected and harmless, so it is swallowed below; the log line after
        // the try/catch then prints a clean single line instead of a cancellation stack trace.
        try
        {
            using var timer = new PeriodicTimer(TimeSpan.FromSeconds(5));

            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                logger.LogInformation("Worker ran at {Timestamp:o}", DateTimeOffset.UtcNow);
            }
        }
        catch (OperationCanceledException)
        {
            // Expected during host shutdown; fall through to the log line below.
        }

        logger.LogInformation("Worker stopping.");
    }
}
