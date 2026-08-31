using System.Globalization;
using Kongroo.SampleApp.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Serilog;
#if (observability)
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
#endif

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddSerilog(configuration =>
    configuration
        .ReadFrom.Configuration(builder.Configuration)
        .WriteTo.Console(formatProvider: CultureInfo.InvariantCulture)
        .Enrich.FromLogContext()
        .Enrich.WithEnvironmentName()
        .Enrich.WithEnvironmentUserName()
        .Enrich.WithMachineName()
        .Enrich.WithProcessId()
        .Enrich.WithProcessName()
        .Enrich.WithThreadId()
        .Enrich.WithThreadName()
        .Enrich.WithProperty("Application", AppDomain.CurrentDomain.FriendlyName)
);

#if (observability)
builder
    .Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource.AddService(builder.Environment.ApplicationName))
    .WithTracing(static tracing => tracing.AddHttpClientInstrumentation().AddOtlpExporter())
    .WithMetrics(static metrics =>
        metrics.AddHttpClientInstrumentation().AddRuntimeInstrumentation().AddOtlpExporter()
    );
#endif

builder.Services.AddHostedService<SampleWorker>();

var host = builder.Build();

await host.RunAsync();
