using DK.EasyRenamer.Core;
using Xunit;

namespace DK.EasyRenamer.Core.Tests;

public sealed class StableReleaseParserTests
{
    private const string Valid = """
        {"tag_name":"v0.2.0","html_url":"https://github.com/danhk0612/DK-Easy-Renamer/releases/tag/v0.2.0","draft":false,"prerelease":false}
        """;

    [Fact]
    public void StableOfficialReleaseIsNewer()
    {
        StableRelease release = Assert.IsType<StableRelease>(StableReleaseParser.ParseLatest(Valid));
        Assert.Equal("v0.2.0", release.Tag);
        Assert.True(StableReleaseParser.HasUpdate(release, new Version(0, 1, 1)));
        Assert.False(StableReleaseParser.HasUpdate(release, new Version(0, 2, 0)));
        Assert.False(StableReleaseParser.HasUpdate(release, new Version(0, 3, 0)));
    }

    [Theory]
    [InlineData("""{"tag_name":"v0.2.0-beta","html_url":"https://github.com/danhk0612/DK-Easy-Renamer/releases/tag/v0.2.0-beta"}""")]
    [InlineData("""{"tag_name":"v0.2.0","html_url":"https://evil.example/releases/tag/v0.2.0"}""")]
    [InlineData("""{"tag_name":"v0.2.0","html_url":"http://github.com/danhk0612/DK-Easy-Renamer/releases/tag/v0.2.0"}""")]
    [InlineData("""{"tag_name":"v0.2.0","html_url":"https://github.com/danhk0612/DK-Easy-Renamer/releases/tag/other"}""")]
    [InlineData("""{"tag_name":"v0.2.0","html_url":"https://github.com@evil.example/danhk0612/DK-Easy-Renamer/releases/tag/v0.2.0"}""")]
    [InlineData("""{"tag_name":"v0.2.0","html_url":"https://github.com/danhk0612/DK-Easy-Renamer/releases/tag/v0.2.0?redirect=1"}""")]
    [InlineData("""{"tag_name":"v0.2.0","html_url":"https://github.com/danhk0612/DK-Easy-Renamer/releases/tag/v0.2.0","draft":true}""")]
    [InlineData("""{"tag_name":"v0.2.0","html_url":"https://github.com/danhk0612/DK-Easy-Renamer/releases/tag/v0.2.0","prerelease":true}""")]
    public void RejectsUntrustedOrUnstableRelease(string json) =>
        Assert.Null(StableReleaseParser.ParseLatest(json));

    [Fact]
    public void ReleaseNotesAreDisplayOnlyText()
    {
        const string json = """
            {"tag_name":"v0.2.0","html_url":"https://github.com/danhk0612/DK-Easy-Renamer/releases/tag/v0.2.0","body":"- Fixed ordering\\n- Improved menu"}
            """;
        StableRelease release = Assert.IsType<StableRelease>(StableReleaseParser.ParseLatest(json));
        Assert.Equal("- Fixed ordering\\n- Improved menu", release.ReleaseNotes);
    }

    [Fact]
    public void MissingOrInvalidBodyLeavesReleaseNotesEmpty()
    {
        Assert.Equal(string.Empty, Assert.IsType<StableRelease>(
            StableReleaseParser.ParseLatest(Valid)).ReleaseNotes);
        string json = Valid.Replace("\"prerelease\":false", "\"prerelease\":false,\"body\":42");
        Assert.Equal(string.Empty, Assert.IsType<StableRelease>(
            StableReleaseParser.ParseLatest(json)).ReleaseNotes);
    }

    [Fact]
    public void MissingFieldsAreNotConsideredUpdates() =>
        Assert.Null(StableReleaseParser.ParseLatest("{}"));

    [Fact]
    public void NoVersionFourPartTag() =>
        Assert.Null(StableReleaseParser.ParseLatest(
            """{"tag_name":"v0.2.0.1","html_url":"https://github.com/danhk0612/DK-Easy-Renamer/releases/tag/v0.2.0.1"}"""));
}
