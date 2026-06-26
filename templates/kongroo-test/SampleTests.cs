using Shouldly;
using Xunit;

namespace Kongroo.SampleApp.UnitTests;

public class SampleTests
{
    [Fact]
    public void Sample_value_is_correct()
    {
        var value = new Bogus.Faker().Random.Int(1, 1);
        value.ShouldBe(1);
    }
}
