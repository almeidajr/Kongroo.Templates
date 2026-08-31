using Spectre.Console.Cli;

namespace Kongroo.SampleApp.Cli.Infrastructure;

/// <summary>Resolves command dependencies out of the built service provider.</summary>
public sealed class TypeResolver(IServiceProvider provider) : ITypeResolver, IDisposable
{
    // Spectre passes null here for absent types — return null rather than throwing.
    public object? Resolve(Type? type) => type is null ? null : provider.GetService(type);

    public void Dispose()
    {
        if (provider is IDisposable disposable)
        {
            disposable.Dispose();
        }
    }
}
