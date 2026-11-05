using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using DK.EasyRenamer.Core;
using Xunit;

namespace DK.EasyRenamer.Core.Tests;

public sealed class VerifiedInstallerDownloaderTests
{
    private const string FileName = "DK-Easy-Renamer-0.2.0-x64-RELEASE.exe";
    private const string OfficialUri =
        "https://github.com/danhk0612/DK-Easy-Renamer/releases/download/v0.2.0/" + FileName;
    private static readonly byte[] Bytes = Encoding.UTF8.GetBytes(
        "A disposable fake installer fixture: never run it as an executable.");

    private static OfficialInstallerAsset Asset() => new(
        FileName,
        new Uri(OfficialUri),
        Bytes.Length,
        Convert.ToHexString(SHA256.HashData(Bytes)));

    private sealed class StubHandler(
        Func<HttpRequestMessage, HttpResponseMessage> handler) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            HttpResponseMessage response = handler(request);
            response.RequestMessage ??= request;
            return Task.FromResult(response);
        }
    }

    private static HttpResponseMessage Content(byte[] bytes) =>
        new(HttpStatusCode.OK) { Content = new ByteArrayContent(bytes) };

    private static string NewRoot() => Path.Combine(Path.GetTempPath(),
        "DK-Easy-Renamer-UpdateFixture-" + Guid.NewGuid().ToString("N"));

    private static void Cleanup(string root)
    {
        if (Directory.Exists(root))
            Directory.Delete(root, recursive: true);
    }

    [Fact]
    public async Task OfficialRedirectAndExactHashProduceOneIsolatedVerifiedFile()
    {
        int requests = 0;
        using var client = new HttpClient(new StubHandler(request =>
        {
            requests++;
            if (requests == 1)
            {
                Assert.Equal("github.com", request.RequestUri!.Host);
                var redirect = new HttpResponseMessage(HttpStatusCode.Redirect);
                redirect.Headers.Location = new Uri(
                    "https://release-assets.githubusercontent.com/asset?token=fixture");
                return redirect;
            }

            Assert.Equal("release-assets.githubusercontent.com", request.RequestUri!.Host);
            return Content(Bytes);
        }));
        string root = NewRoot();
        try
        {
            string path = await VerifiedInstallerDownloader.DownloadAsync(client, Asset(), root);
            Assert.Equal(2, requests);
            Assert.Equal(FileName, Path.GetFileName(path));
            Assert.Equal(Bytes, await File.ReadAllBytesAsync(path));
            Assert.Single(Directory.GetFiles(root, "*.exe", SearchOption.AllDirectories));
            Assert.Empty(Directory.GetFiles(root, "*.part", SearchOption.AllDirectories));
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task IncorrectDigestRejectsSameLengthTamperingAndCleansTemporaryFiles()
    {
        byte[] changed = Bytes.ToArray();
        changed[0] ^= 0x01;
        using var client = new HttpClient(new StubHandler(_ => Content(changed)));
        string root = NewRoot();
        try
        {
            await Assert.ThrowsAsync<InvalidDataException>(() =>
                VerifiedInstallerDownloader.DownloadAsync(client, Asset(), root));
            Assert.Empty(Directory.GetFiles(root, "*", SearchOption.AllDirectories));
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task WrongAdvertisedSizeIsRejectedBeforeStaging()
    {
        byte[] larger = Bytes.Concat(new byte[] { 0x42 }).ToArray();
        using var client = new HttpClient(new StubHandler(_ => Content(larger)));
        string root = NewRoot();
        try
        {
            await Assert.ThrowsAsync<InvalidDataException>(() =>
                VerifiedInstallerDownloader.DownloadAsync(client, Asset(), root));
            Assert.Empty(Directory.GetFiles(root, "*", SearchOption.AllDirectories));
        }
        finally { Cleanup(root); }
    }

    [Theory]
    [InlineData("https://evil.example/installer.exe")]
    [InlineData("http://release-assets.githubusercontent.com/installer.exe")]
    [InlineData("https://evil.example@release-assets.githubusercontent.com/installer.exe")]
    [InlineData("https://release-assets.githubusercontent.com:8443/installer.exe")]
    [InlineData("https://cdn.example.org/installer.exe")]
    [InlineData("https://github.com/danhk0612/DK-Easy-Renamer/releases/latest")]
    public async Task UnapprovedRedirectIsRejectedWithoutSavingFile(string destination)
    {
        using var client = new HttpClient(new StubHandler(_ =>
        {
            var response = new HttpResponseMessage(HttpStatusCode.Redirect);
            response.Headers.Location = new Uri(destination);
            return response;
        }));
        string root = NewRoot();
        try
        {
            await Assert.ThrowsAsync<InvalidDataException>(() =>
                VerifiedInstallerDownloader.DownloadAsync(client, Asset(), root));
            Assert.Empty(Directory.GetFiles(root, "*", SearchOption.AllDirectories));
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task TransparentClientRedirectIsNotTrusted()
    {
        using var client = new HttpClient(new StubHandler(_ =>
        {
            var response = Content(Bytes);
            response.RequestMessage = new HttpRequestMessage(
                HttpMethod.Get, "https://evil.example/installer.exe");
            return response;
        }));
        string root = NewRoot();
        try
        {
            await Assert.ThrowsAsync<InvalidDataException>(() =>
                VerifiedInstallerDownloader.DownloadAsync(client, Asset(), root));
            Assert.Empty(Directory.GetFiles(root, "*", SearchOption.AllDirectories));
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task InfiniteRedirectChainFailsClosed()
    {
        using var client = new HttpClient(new StubHandler(_ =>
        {
            var response = new HttpResponseMessage(HttpStatusCode.Redirect);
            response.Headers.Location = new Uri(
                "https://objects.githubusercontent.com/asset?token=fixture");
            return response;
        }));
        string root = NewRoot();
        try
        {
            await Assert.ThrowsAsync<InvalidDataException>(() =>
                VerifiedInstallerDownloader.DownloadAsync(client, Asset(), root));
            Assert.Empty(Directory.GetFiles(root, "*", SearchOption.AllDirectories));
        }
        finally { Cleanup(root); }
    }

    [Theory]
    [InlineData("http://github.com/danhk0612/DK-Easy-Renamer/releases/download/v0.2.0/")]
    [InlineData("https://evil.example/danhk0612/DK-Easy-Renamer/releases/download/v0.2.0/")]
    public async Task ForgedOriginalDownloadAddressIsRejected(string prefix)
    {
        var forged = Asset() with { DownloadUrl = new Uri(prefix + FileName) };
        using var client = new HttpClient(new StubHandler(_ =>
            throw new InvalidOperationException("Network must not be requested.")));
        string root = NewRoot();
        await Assert.ThrowsAsync<InvalidDataException>(() =>
            VerifiedInstallerDownloader.DownloadAsync(client, forged, root));
        Assert.False(Directory.Exists(root));
    }

    [Fact]
    public async Task CanceledRequestDoesNotCreateTemporaryFiles()
    {
        using var cancel = new CancellationTokenSource();
        cancel.Cancel();
        using var client = new HttpClient(new StubHandler(_ =>
            throw new InvalidOperationException("Network must not be requested.")));
        string root = NewRoot();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            VerifiedInstallerDownloader.DownloadAsync(client, Asset(), root, cancel.Token));
        Assert.False(Directory.Exists(root));
    }

    [Fact]
    public async Task RejectsOversizedMetadataBeforeNetworkOrDisk()
    {
        var invalid = Asset() with { Size = 1024L * 1024 * 1024 };
        using var client = new HttpClient(new StubHandler(_ =>
            throw new InvalidOperationException("Network must not be requested.")));
        string root = NewRoot();
        await Assert.ThrowsAsync<InvalidDataException>(() =>
            VerifiedInstallerDownloader.DownloadAsync(client, invalid, root));
        Assert.False(Directory.Exists(root));
    }
}
