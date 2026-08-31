using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Kongroo.SampleApp.Worker;

/// <summary>Placeholder background service — replace with your own work loop.</summary>
public sealed class SampleWorker(ILogger<SampleWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Cancelling stoppingToken makes WaitForNextTickAsync throw OperationCanceledException,
        // which the host treats as a normal shutdown — this deliberately has no catch.
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(5));

        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            logger.LogInformation("Worker ran at {Timestamp:o}", DateTimeOffset.UtcNow);
        }
    }
}
