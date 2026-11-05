using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using DK.EasyRenamer.Core;
using Xunit;

namespace DK.EasyRenamer.Core.Tests;

public sealed class PublicUpdatePolicyTests
{
    private const string Filename = "DK-Easy-Renamer-0.2.0-x64-RELEASE.exe";

    private static string ReleaseJson(bool withAsset, bool prerelease = false)
    {
        byte[] data = Encoding.UTF8.GetBytes("fake fixture; not an executable");
        return JsonSerializer.Serialize(new
        {
            tag_name = "v0.2.0",
            html_url = "https://github.com/danhk0612/DK-Easy-Renamer/releases/tag/v0.2.0",
            draft = false,
            prerelease,
            assets = withAsset ? new[]
            {
                new
                {
                    name = Filename,
                    browser_download_url = "https://github.com/danhk0612/DK-Easy-Renamer/releases/download/v0.2.0/" + Filename,
                    state = "uploaded",
                    size = data.Length,
                    digest = "sha256:" + Convert.ToHexString(SHA256.HashData(data)).ToLowerInvariant()
                }
            } : []
        });
    }

    [Fact]
    public void PublicInstallerNameIsExact()
    {
        Assert.Equal(Filename, PublicUpdatePolicy.InstallerFileName(new Version(0, 2, 0)));
    }

    [Fact]
    public void ChoosesOnlyNewerValidStableOfficialInstaller()
    {
        string json = ReleaseJson(withAsset: true);
        Assert.NotNull(PublicUpdatePolicy.FindNewerInstaller(json, new Version(0, 1, 2)));
        Assert.Null(PublicUpdatePolicy.FindNewerInstaller(json, new Version(0, 2, 0)));
        Assert.Null(PublicUpdatePolicy.FindNewerInstaller(json, new Version(0, 3, 0)));
        Assert.Null(PublicUpdatePolicy.FindNewerInstaller(ReleaseJson(withAsset: false), new Version(0, 1, 2)));
        Assert.Null(PublicUpdatePolicy.FindNewerInstaller(ReleaseJson(withAsset: true, prerelease: true), new Version(0, 1, 2)));
    }

    [Fact]
    public void UnapprovedPublicPublisherCannotAuthorizeAutoInstallation()
    {
        Assert.False(PublicUpdatePolicy.TryGetApprovedPublisher(out PublicUpdatePublisher? publisher));
        Assert.Null(publisher);
    }
}
