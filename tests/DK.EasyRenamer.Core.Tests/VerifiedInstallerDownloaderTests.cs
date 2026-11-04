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
    private static readonly byte[] Fixture = Encoding.UTF8.GetBytes("safe disposable bytes, not an executable");

    private static OfficialInstallerAsset Asset(byte[]? bytes = null) =>
        new(FileName,
            new Uri("https://github.com/danhk0612/DK-Easy-Renamer/releases/download/v0.2.0/" + FileName),
            (bytes ?? Fixture).Length,
            Convert.ToHexString(SHA256.HashData(bytes ?? Fixture)));

    private sealed class Handler(Func<HttpRequestMessage, HttpResponseMessage> reply) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            HttpResponseMessage response = reply(request);
            response.RequestMessage = request;
            return Task.FromResult(response);
        }
    }

    private static HttpResponseMessage FileResponse(byte[] data) =>
        new(HttpStatusCode.OK) { Content = new ByteArrayContent(data) };

    private static string FreshTestRoot() => Path.Combine(
        Path.GetTempPath(), "DK-Easy-Renamer-UpdateTest-" + Guid.NewGuid().ToString("N"));

    [Fact]
    public async Task ValidOfficialRedirectAndCorrectDigestCreateOneStagedFile()
    {
        int called = 0;
        using var client = new HttpClient(new Handler(request =>
        {
            called++;
            if (called == 1)
            {
                Assert.Equal("github.com", request.RequestUri!.Host);
                var redirect = new HttpResponseMessage(HttpStatusCode.Redirect);
                redirect.Headers.Location =
                    new Uri("https://release-assets.githubusercontent.com/fixture?id=123");
                return redirect;
            }
            Assert.Equal("release-assets.githubusercontent.com", request.RequestUri!.Host);
            return FileResponse(Fixture);
        }));
        string root = FreshTestRoot();
        try
        {
            string path = await VerifiedInstallerDownloader.DownloadAsync(client, Asset(), root);
            Assert.Equal(2, called);
            Assert.Equal(FileName, Path.GetFileName(path));
            Assert.Equal(Fixture, await File.ReadAllBytesAsync(path));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }

    [Theory]
    [InlineData("https://evil.example/installer.exe")]
    [InlineData("http://release-assets.githubusercontent.com/installer")]
    [InlineData("https://github.com@evil.example/installer")]
    [InlineData("https://release-assets.githubusercontent.com:8443/installer")]
    public async Task UntrustedRedirectIsRejectedAndTemporaryFilesRemoved(string redirected)
    {
        using var client = new HttpClient(new Handler(_ =>
        {
            var response = new HttpResponseMessage(HttpStatusCode.Redirect);
            response.Headers.Location = new Uri(redirected);
            return response;
        }));
        string root = FreshTestRoot();
        await Assert.ThrowsAsync<InvalidDataException>(() =>
            VerifiedInstallerDownloader.DownloadAsync(client, Asset(), root));
        Assert.Empty(Directory.GetFiles(root, "*", SearchOption.AllDirectories));
        Directory.Delete(root, true);
    }

    [Fact]
    public async Task TamperedContentFailsAndDeletesPartialFile()
    {
        using var client = new HttpClient(new Handler(_ =>
            FileResponse(Encoding.UTF8.GetBytes("same size but corrupted fixture payload"))));
        string root = FreshTestRoot();
        try
        {
            await Assert.ThrowsAsync<InvalidDataException>(() =>
                VerifiedInstallerDownloader.DownloadAsync(client, Asset(), root));
            Assert.Empty(Directory.GetFiles(root, "*", SearchOption.AllDirectories));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }

    [Fact]
    public async Task OversizedBodyIsRejectedBeforeItIsInstalled()
    {
        using var client = new HttpClient(new Handler(_ => FileResponse(new byte[Fixture.Length + 100])));
        string root = FreshTestRoot();
        try
        {
            await Assert.ThrowsAsync<InvalidDataException>(() =>
                VerifiedInstallerDownloader.DownloadAsync(client, Asset(), root));
            Assert.Empty(Directory.GetFiles(root, "*", SearchOption.AllDirectories));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }

    [Fact]
    public async Task UserCancellationDoesNotWriteAnInstaller()
    {
        using var client = new HttpClient(new Handler(_ => FileResponse(Fixture)));
        using var canceled = new CancellationTokenSource();
        canceled.Cancel();
        string root = FreshTestRoot();
        try
        {
            await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
                VerifiedInstallerDownloader.DownloadAsync(client, Asset(), root, canceled.Token));
            Assert.Empty(Directory.GetFiles(root, "*", SearchOption.AllDirectories));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }
}
