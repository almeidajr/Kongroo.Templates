using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Kongroo.SampleApp.Worker;

/// <summary>Placeholder background service — replace with your own work loop.</summary>
public sealed class SampleWorker(ILogger<SampleWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // PeriodicTimer over Task.Delay: it does not drift, and the single catch below
        // turns shutdown into a clean log line instead of a cancellation stack trace.
        try
        {
            using var timer = new PeriodicTimer(TimeSpan.FromSeconds(5));

            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                logger.LogInformation("Worker ran at {Timestamp:o}", DateTimeOffset.UtcNow);
            }
        }
        catch (OperationCanceledException ex)
        {
            logger.LogInformation(ex, "Worker stopping.");
        }
    }
}
