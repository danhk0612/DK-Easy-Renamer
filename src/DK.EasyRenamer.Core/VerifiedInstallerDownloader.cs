using System.Buffers;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;

namespace DK.EasyRenamer.Core;

/// <summary>
/// Downloads one validated GitHub Release asset to a unique staging folder.
/// This verifies transport, size and digest, but does not authorize execution:
/// the caller must separately verify Authenticode and a pinned public signer.
/// </summary>
public static class VerifiedInstallerDownloader
{
    private const long MaximumInstallerBytes = 512L * 1024 * 1024;

    public static async Task<string> DownloadAsync(
        HttpClient client,
        OfficialInstallerAsset asset,
        string stagingRoot,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(client);
        ArgumentNullException.ThrowIfNull(asset);
        if (asset.Size is <= 0 or > MaximumInstallerBytes ||
            asset.Sha256.Length != 64 ||
            !UriIsTrusted(asset.DownloadUrl, initial: true))
            throw new InvalidDataException("The installer metadata is not approved.");

        // No shared filenames, no overwrite of a previous download.
        string directory = Path.Combine(stagingRoot, Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        string partial = Path.Combine(directory, "download.part");
        string result = Path.Combine(directory, asset.FileName);

        try
        {
            Uri location = asset.DownloadUrl;
            for (int redirect = 0; redirect <= 5; redirect++)
            {
                using var request = new HttpRequestMessage(HttpMethod.Get, location);
                using HttpResponseMessage response = await client.SendAsync(
                    request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);

                // The HttpClient used by the updater must disable automatic redirects.
                if (response.RequestMessage?.RequestUri != location)
                    throw new InvalidDataException("Unreviewed HTTP redirect detected.");

                if (response.StatusCode is HttpStatusCode.MovedPermanently or
                    HttpStatusCode.Redirect or HttpStatusCode.RedirectMethod or
                    HttpStatusCode.TemporaryRedirect or HttpStatusCode.PermanentRedirect)
                {
                    Uri? next = response.Headers.Location;
                    if (next is null)
                        throw new InvalidDataException("Release redirect has no destination.");
                    if (!next.IsAbsoluteUri)
                        next = new Uri(location, next);
                    if (!UriIsTrusted(next, initial: false))
                        throw new InvalidDataException("Release download redirected to an untrusted host.");
                    location = next;
                    continue;
                }

                if (response.StatusCode != HttpStatusCode.OK)
                    throw new HttpRequestException("Release download was not successful.");

                if (response.Content.Headers.ContentLength is long advertised &&
                    advertised != asset.Size)
                    throw new InvalidDataException("Installer size differs from the official release.");

                long received = 0;
                using var digest = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
                await using (var target = new FileStream(
                    partial, FileMode.CreateNew, FileAccess.Write, FileShare.None,
                    81920, FileOptions.Asynchronous))
                await using (Stream source = await response.Content.ReadAsStreamAsync(cancellationToken))
                {
                    byte[] buffer = ArrayPool<byte>.Shared.Rent(81920);
                    try
                    {
                        int read;
                        while ((read = await source.ReadAsync(buffer.AsMemory(), cancellationToken)) != 0)
                        {
                            received += read;
                            if (received > asset.Size)
                                throw new InvalidDataException("Installer download exceeded the expected size.");
                            await target.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
                            digest.AppendData(buffer, 0, read);
                        }
                    }
                    finally { ArrayPool<byte>.Shared.Return(buffer); }
                }

                if (received != asset.Size ||
                    !CryptographicOperations.FixedTimeEquals(
                        digest.GetHashAndReset(), Convert.FromHexString(asset.Sha256)))
                    throw new InvalidDataException("Installer SHA-256 or size is invalid.");

                File.Move(partial, result);
                return result;
            }
            throw new InvalidDataException("Too many release redirects.");
        }
        catch
        {
            if (Directory.Exists(directory))
                Directory.Delete(directory, recursive: true);
            throw;
        }
    }

    private static bool UriIsTrusted(Uri uri, bool initial)
    {
        if (uri.Scheme != Uri.UriSchemeHttps || !uri.IsDefaultPort ||
            uri.UserInfo.Length != 0 || uri.Fragment.Length != 0)
            return false;

        if (initial)
            return string.Equals(uri.Host, "github.com", StringComparison.OrdinalIgnoreCase) &&
                uri.Query.Length == 0 &&
                uri.AbsolutePath.StartsWith(
                    "/danhk0612/DK-Easy-Renamer/releases/download/", StringComparison.Ordinal);

        // GitHub releases currently use a signed, expiring CDN URL for asset bytes.
        return string.Equals(uri.Host, "release-assets.githubusercontent.com", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(uri.Host, "objects.githubusercontent.com", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(uri.Host, "github.com", StringComparison.OrdinalIgnoreCase);
    }
}
