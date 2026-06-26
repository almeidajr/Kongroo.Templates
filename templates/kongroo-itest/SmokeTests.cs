using Bogus;
using Shouldly;
using Xunit;

namespace Kongroo.SampleApp.IntegrationTests;

// Placeholder smoke test — replace with real integration tests.
// Once you reference an app under test, use WebApplicationFactory<Program> (Mvc.Testing)
// and/or Testcontainers (both already referenced) to exercise real endpoints and dependencies.
public class SmokeTests
{
    [Fact]
    public void RandomInt_WhenGivenARange_ShouldReturnValueWithinThatRange()
    {
        var value = new Faker().Random.Int(1, 100);

        value.ShouldBeInRange(1, 100);
    }
}
