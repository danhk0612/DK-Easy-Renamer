using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using DK.EasyRenamer.Core;
using Xunit;

namespace DK.EasyRenamer.Core.Tests;

public sealed class OfficialInstallerAssetVerifierTests
{
    private const string Filename = "DK-Easy-Renamer-0.2.0-x64-RELEASE.exe";
    private static readonly byte[] InstallerBytes = Encoding.UTF8.GetBytes("disposable fixture; not an executable");
    private static readonly string Digest = Convert.ToHexString(SHA256.HashData(InstallerBytes)).ToLowerInvariant();

    private static string ReleaseJson(string fileName = Filename)
    {
        return JsonSerializer.Serialize(new
        {
            tag_name = "v0.2.0",
            html_url = "https://github.com/danhk0612/DK-Easy-Renamer/releases/tag/v0.2.0",
            draft = false,
            prerelease = false,
            assets = new[]
            {
                new
                {
                    name = fileName,
                    browser_download_url =
                        $"https://github.com/danhk0612/DK-Easy-Renamer/releases/download/v0.2.0/{fileName}",
                    state = "uploaded",
                    size = InstallerBytes.Length,
                    digest = "sha256:" + Digest
                }
            }
        });
    }

    [Fact]
    public void AcceptsSingleOfficialReleaseAssetAndCorrectBytes()
    {
        OfficialInstallerAsset asset = Assert.IsType<OfficialInstallerAsset>(
            OfficialInstallerAssetVerifier.Find(ReleaseJson(), Filename));
        Assert.Equal(Filename, asset.FileName);
        Assert.Equal(Digest.ToUpperInvariant(), asset.Sha256);
        Assert.Equal(InstallerBytes.Length, asset.Size);
        using var stream = new MemoryStream(InstallerBytes);
        Assert.True(OfficialInstallerAssetVerifier.VerifySha256(stream, asset));
    }

    [Fact]
    public void RejectsTamperedDownloadContent()
    {
        OfficialInstallerAsset asset = Assert.IsType<OfficialInstallerAsset>(
            OfficialInstallerAssetVerifier.Find(ReleaseJson(), Filename));
        using var stream = new MemoryStream(Encoding.UTF8.GetBytes("tampered"));
        Assert.False(OfficialInstallerAssetVerifier.VerifySha256(stream, asset));
    }

    [Theory]
    [InlineData("DK-Easy-Renamer-0.2.0-x64-SIGNED-PROBE.exe")]
    [InlineData("DK-Easy-Renamer-0.2.0-x64-UNSIGNED-DO-NOT-INSTALL.exe")]
    [InlineData("DK-Easy-Renamer-0.2.0-x64-DEV.exe")]
    [InlineData("DK-Easy-Renamer-0.2.0-x64-TEST.exe")]
    [InlineData("DK-Easy-Renamer-0.1.2-x64-RELEASE.exe")]
    [InlineData("../../DK-Easy-Renamer-0.2.0-x64-RELEASE.exe")]
    [InlineData("DK-Easy-Renamer-0.2.0-x64-RELEASE.msi")]
    public void RejectsTestAndUnexpectedAssetNames(string name)
    {
        Assert.Null(OfficialInstallerAssetVerifier.Find(ReleaseJson(name), name));
    }

    [Theory]
    [InlineData("https://evil.example/releases/download/v0.2.0/")]
    [InlineData("http://github.com/danhk0612/DK-Easy-Renamer/releases/download/v0.2.0/")]
    [InlineData("https://github.com@evil.example/danhk0612/DK-Easy-Renamer/releases/download/v0.2.0/")]
    [InlineData("https://github.com/danhk0612/DK-Easy-Renamer/releases/download/v0.1.9/")]
    [InlineData("https://github.com/danhk0612/DK-Easy-Renamer/releases/download/v0.2.0/other-")]
    [InlineData("https://github.com/danhk0612/DK-Easy-Renamer/releases/download/v0.2.0/?next=")]
    public void RejectsUntrustedOrMismatchedDownloadUrl(string prefix)
    {
        string json = ReleaseJson().Replace(
            "https://github.com/danhk0612/DK-Easy-Renamer/releases/download/v0.2.0/",
            prefix, StringComparison.Ordinal);
        Assert.Null(OfficialInstallerAssetVerifier.Find(json, Filename));
    }

    [Fact]
    public void RejectsMissingDigestAndIncorrectLifecycleState()
    {
        string json = ReleaseJson();
        Assert.Null(OfficialInstallerAssetVerifier.Find(
            json.Replace("sha256:" + Digest, "sha1:" + Digest), Filename));
        Assert.Null(OfficialInstallerAssetVerifier.Find(
            json.Replace("\"uploaded\"", "\"starter\""), Filename));
        Assert.Null(OfficialInstallerAssetVerifier.Find(
            json.Replace("\"size\":" + InstallerBytes.Length, "\"size\":0"), Filename));
    }

    [Fact]
    public void RejectsDuplicateAssetNames()
    {
        using JsonDocument doc = JsonDocument.Parse(ReleaseJson());
        string asset = doc.RootElement.GetProperty("assets")[0].GetRawText();
        string json = ReleaseJson().Replace("\"assets\":[" + asset + "]", "\"assets\":[" + asset + "," + asset + "]");
        Assert.Null(OfficialInstallerAssetVerifier.Find(json, Filename));
    }

    [Fact]
    public void RejectsPrereleaseAndDraftEvenWithValidAssets()
    {
        string json = ReleaseJson();
        Assert.Null(OfficialInstallerAssetVerifier.Find(
            json.Replace("\"prerelease\":false", "\"prerelease\":true"), Filename));
        Assert.Null(OfficialInstallerAssetVerifier.Find(
            json.Replace("\"draft\":false", "\"draft\":true"), Filename));
    }

    [Fact]
    public void RejectsMissingAssetsOrWrongFileSelection()
    {
        Assert.Null(OfficialInstallerAssetVerifier.Find(
            ReleaseJson(), "DK-Easy-Renamer-0.2.0-x64-OTHER.exe"));
        Assert.Null(OfficialInstallerAssetVerifier.Find(
            ReleaseJson().Replace("\"assets\":", "\"not_assets\":"), Filename));
    }
}
