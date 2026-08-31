using System.ComponentModel;
using Spectre.Console;
using Spectre.Console.Cli;

namespace Kongroo.SampleApp.Cli.Commands;

/// <summary>Placeholder command — replace with your own.</summary>
public sealed class GreetCommand(IAnsiConsole console) : AsyncCommand<GreetCommand.Settings>
{
    // protected, and three parameters, in Spectre.Console.Cli 0.55. `public override` will not
    // compile, and neither will the two-parameter form most published examples show.
    protected override Task<int> ExecuteAsync(
        CommandContext context,
        Settings settings,
        CancellationToken cancellationToken
    )
    {
        ArgumentNullException.ThrowIfNull(settings);

        console.MarkupLineInterpolated($"Hello, {settings.Name}!");

        return Task.FromResult(0);
    }

    public sealed class Settings : CommandSettings
    {
        [CommandArgument(0, "<NAME>")]
        [Description("Who to greet.")]
        public required string Name { get; init; }
    }
}
