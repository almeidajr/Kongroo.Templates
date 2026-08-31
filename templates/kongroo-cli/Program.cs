using Kongroo.SampleApp.Cli;
using Kongroo.SampleApp.Cli.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Spectre.Console.Cli;

var services = new ServiceCollection();

var app = new CommandApp(new TypeRegistrar(services));

app.Configure(CommandConfiguration.Apply);

return await app.RunAsync(args);
