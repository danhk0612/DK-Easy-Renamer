using System.Buffers;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text.RegularExpressions;

namespace DK.EasyRenamer.Core;

/// <summary>
/// Stages the bytes of a previously selected official release asset.
/// A valid hash does NOT authorize execution: trusted Authenticode and publisher
/// verification, user consent and a safe installer handoff are separate gates.
/// </summary>
public static class VerifiedInstallerDownloader
{
    private const long MaximumInstallerSize = 512L * 1024 * 1024;
    private const string OfficialDownloadPrefix =
        "/danhk0612/DK-Easy-Renamer/releases/download/";

    /// <summary>
    /// Caller must supply an HttpClient with automatic redirects DISABLED
    /// (HttpClientHandler.AllowAutoRedirect=false). Redirects are checked here.
    /// No installer is ever launched; only an isolated verified file is returned.
    /// </summary>
    public static async Task<string> DownloadAsync(
        HttpClient client,
        OfficialInstallerAsset asset,
        string stagingRoot,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(client);
        ArgumentNullException.ThrowIfNull(asset);
        ArgumentException.ThrowIfNullOrWhiteSpace(stagingRoot);

        if (asset.Size <= 0 || asset.Size > MaximumInstallerSize ||
            !Regex.IsMatch(asset.FileName,
                @"^DK-Easy-Renamer-\d+\.\d+\.\d+-x64-[A-Za-z0-9_-]+\.exe$",
                RegexOptions.CultureInvariant) ||
            !Regex.IsMatch(asset.Sha256, @"^[a-fA-F0-9]{64}$",
                RegexOptions.CultureInvariant) ||
            !IsOriginalGitHubAssetUrl(asset.DownloadUrl, asset.FileName))
            throw new InvalidDataException("Official installer asset metadata is invalid.");

        cancellationToken.ThrowIfCancellationRequested();
        // Never choose a shared file name or touch an existing staged installer.
        string uniqueDirectory = Path.Combine(stagingRoot, Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(uniqueDirectory);
        string partialFile = Path.Combine(uniqueDirectory, "download.part");
        string verifiedFile = Path.Combine(uniqueDirectory, asset.FileName);

        try
        {
            Uri location = asset.DownloadUrl;
            for (int redirects = 0; redirects <= 5; redirects++)
            {
                cancellationToken.ThrowIfCancellationRequested();
                using var request = new HttpRequestMessage(HttpMethod.Get, location);
                using var response = await client.SendAsync(
                    request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);

                // Fail closed if the supplied HttpClient followed any redirect itself.
                if (response.RequestMessage?.RequestUri != location)
                    throw new InvalidDataException("HTTP redirects must be inspected before following.");

                if (response.StatusCode is HttpStatusCode.MovedPermanently
                    or HttpStatusCode.Redirect
                    or HttpStatusCode.RedirectMethod
                    or HttpStatusCode.TemporaryRedirect
                    or HttpStatusCode.PermanentRedirect)
                {
                    Uri? next = response.Headers.Location;
                    if (next is null)
                        throw new InvalidDataException("GitHub asset redirect has no location.");
                    if (!next.IsAbsoluteUri)
                        next = new Uri(location, next);
                    if (!IsAllowedRedirect(next))
                        throw new InvalidDataException("GitHub asset redirect is not trusted.");
                    location = next;
                    continue;
                }

                if (response.StatusCode != HttpStatusCode.OK)
                    throw new HttpRequestException("GitHub release asset could not be downloaded.");

                if (response.Content.Headers.ContentLength is long advertised &&
                    advertised != asset.Size)
                    throw new InvalidDataException("Installer content length mismatch.");

                long received = 0;
                using var sha256 = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
                await using (var target = new FileStream(
                    partialFile, FileMode.CreateNew, FileAccess.Write,
                    FileShare.None, 81920, FileOptions.Asynchronous))
                await using (var source = await response.Content.ReadAsStreamAsync(cancellationToken))
                {
                    byte[] buffer = ArrayPool<byte>.Shared.Rent(81920);
                    try
                    {
                        int count;
                        while ((count = await source.ReadAsync(
                            buffer.AsMemory(), cancellationToken)) != 0)
                        {
                            received += count;
                            if (received > asset.Size)
                                throw new InvalidDataException("Installer exceeds its declared size.");
                            await target.WriteAsync(buffer.AsMemory(0, count), cancellationToken);
                            sha256.AppendData(buffer, 0, count);
                        }
                    }
                    finally
                    {
                        ArrayPool<byte>.Shared.Return(buffer);
                    }
                }

                byte[] expected = Convert.FromHexString(asset.Sha256);
                if (received != asset.Size ||
                    !CryptographicOperations.FixedTimeEquals(sha256.GetHashAndReset(), expected))
                    throw new InvalidDataException("Installer size or SHA-256 does not match.");

                File.Move(partialFile, verifiedFile);
                return verifiedFile;
            }

            throw new InvalidDataException("Too many asset redirects.");
        }
        catch
        {
            // This directory was newly created by this invocation only.
            // Never clean unrelated user folders or previously staged updates.
            if (Directory.Exists(uniqueDirectory))
                Directory.Delete(uniqueDirectory, recursive: true);
            throw;
        }
    }

    private static bool IsOriginalGitHubAssetUrl(Uri url, string fileName) =>
        url.IsAbsoluteUri &&
        url.Scheme == Uri.UriSchemeHttps &&
        url.IsDefaultPort &&
        url.UserInfo.Length == 0 &&
        url.Query.Length == 0 &&
        url.Fragment.Length == 0 &&
        string.Equals(url.Host, "github.com", StringComparison.OrdinalIgnoreCase) &&
        url.AbsolutePath.StartsWith(OfficialDownloadPrefix, StringComparison.Ordinal) &&
        url.AbsolutePath.EndsWith("/" + fileName, StringComparison.Ordinal);

    private static bool IsAllowedRedirect(Uri url) =>
        url.IsAbsoluteUri &&
        url.Scheme == Uri.UriSchemeHttps &&
        url.IsDefaultPort &&
        url.UserInfo.Length == 0 &&
        url.Fragment.Length == 0 &&
        (string.Equals(url.Host, "release-assets.githubusercontent.com",
            StringComparison.OrdinalIgnoreCase) ||
         string.Equals(url.Host, "objects.githubusercontent.com",
            StringComparison.OrdinalIgnoreCase));
}
