using Microsoft.Extensions.DependencyInjection;
using Spectre.Console.Cli;

namespace Kongroo.SampleApp.Cli.Infrastructure;

/// <summary>Bridges Spectre.Console.Cli onto Microsoft.Extensions.DependencyInjection.</summary>
/// <remarks>Spectre ships no bridge package; this is the documented pattern, hand-written.</remarks>
public sealed class TypeRegistrar(IServiceCollection services) : ITypeRegistrar
{
    public ITypeResolver Build() => new TypeResolver(services.BuildServiceProvider());

    public void Register(Type service, Type implementation) => services.AddSingleton(service, implementation);

    public void RegisterInstance(Type service, object implementation) => services.AddSingleton(service, implementation);

    public void RegisterLazy(Type service, Func<object> factory)
    {
        ArgumentNullException.ThrowIfNull(factory);

        services.AddSingleton(service, _ => factory());
    }
}
