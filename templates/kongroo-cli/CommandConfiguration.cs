using Kongroo.SampleApp.Cli.Commands;
using Spectre.Console;
using Spectre.Console.Cli;

namespace Kongroo.SampleApp.Cli;

/// <summary>
/// The single command registration, shared by <c>Program</c> and any test, so tests exercise the
/// real configuration rather than a copy that drifts away from it.
/// </summary>
public static class CommandConfiguration
{
    public static void Apply(IConfigurator configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration);

        configuration.SetApplicationName("Kongroo.SampleApp.Cli");

        // Without this, -v|--version is silently not wired up at all.
        configuration.UseAssemblyInformationalVersion();

        configuration
            .AddCommand<GreetCommand>("greet")
            .WithDescription("Greet someone by name.")
            .WithExample("greet", "World");

        configuration.SetExceptionHandler(
            static (exception, resolver) =>
            {
                // Null for parse-time failures — an unknown verb never built a container — so the
                // fallback is load-bearing, not defensive noise.
                var console = (IAnsiConsole?)resolver?.Resolve(typeof(IAnsiConsole)) ?? AnsiConsole.Console;

                // Cancellation must be tested first: CommandApp.RunAsync checks for a registered
                // handler BEFORE it checks for OperationCanceledException, so without this branch
                // Ctrl-C reports as a crash with exit code 1 instead of 130.
                if (exception is OperationCanceledException)
                {
                    console.MarkupLine("[yellow]Cancelled.[/]");
                    return 130;
                }

                console.WriteException(exception, ExceptionFormats.ShortenEverything);
                return 1;
            }
        );
    }
}
