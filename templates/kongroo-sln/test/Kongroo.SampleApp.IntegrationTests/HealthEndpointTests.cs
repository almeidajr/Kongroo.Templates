using Microsoft.AspNetCore.Mvc.Testing;
using Shouldly;
using Xunit;

namespace Kongroo.SampleApp.IntegrationTests;

public class HealthEndpointTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task Health_endpoint_returns_healthy()
    {
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/health", TestContext.Current.CancellationToken);
        var body = await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken);

        response.EnsureSuccessStatusCode();
        body.ShouldContain("Healthy");
    }
}
