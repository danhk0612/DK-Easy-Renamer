using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace DK.EasyRenamer.Core;

/// <summary>
/// A candidate official release asset, not authorization to download or execute it.
/// The caller must separately verify the Windows signature and trusted publisher.
/// </summary>
public sealed record OfficialInstallerAsset(string FileName, Uri DownloadUrl, long Size, string Sha256);

public static class OfficialInstallerAssetVerifier
{
    private const string AssetPrefix = "/danhk0612/DK-Easy-Renamer/releases/download/";

    /// <summary>
    /// Reads a uniquely named release asset and its GitHub-provided SHA-256 digest.
    /// The exact public installer filename must be supplied by an approved release policy.
    /// Development probes and unsigned builds are never accepted.
    /// </summary>
    public static OfficialInstallerAsset? Find(string releaseJson, string expectedFileName)
    {
        StableRelease? release = StableReleaseParser.ParseLatest(releaseJson);
        if (release is null)
            return null;

        string prefix = $"DK-Easy-Renamer-{release.Version.ToString(3)}-x64-";
        if (string.IsNullOrEmpty(expectedFileName) ||
            !expectedFileName.StartsWith(prefix, StringComparison.Ordinal) ||
            !Regex.IsMatch(expectedFileName, @"^[A-Za-z0-9._-]+\.exe$", RegexOptions.CultureInvariant) ||
            Regex.IsMatch(expectedFileName, @"(?:^|[-_.])(UNSIGNED|PROBE|TEST|DEV)(?:[-_.]|$)",
                RegexOptions.CultureInvariant | RegexOptions.IgnoreCase))
            return null;

        using JsonDocument doc = JsonDocument.Parse(releaseJson);
        if (!doc.RootElement.TryGetProperty("assets", out JsonElement assets) ||
            assets.ValueKind != JsonValueKind.Array)
            return null;

        OfficialInstallerAsset? match = null;
        foreach (JsonElement asset in assets.EnumerateArray())
        {
            if (asset.ValueKind != JsonValueKind.Object ||
                !asset.TryGetProperty("name", out JsonElement name) ||
                name.ValueKind != JsonValueKind.String ||
                !string.Equals(name.GetString(), expectedFileName, StringComparison.Ordinal))
                continue;

            // Duplicate asset names are ambiguous, even when one is otherwise valid.
            if (match is not null)
                return null;

            if (!asset.TryGetProperty("state", out JsonElement state) ||
                state.ValueKind != JsonValueKind.String || state.GetString() != "uploaded" ||
                !asset.TryGetProperty("size", out JsonElement size) ||
                size.ValueKind != JsonValueKind.Number || !size.TryGetInt64(out long length) ||
                length <= 0 ||
                !asset.TryGetProperty("digest", out JsonElement digest) ||
                digest.ValueKind != JsonValueKind.String ||
                !asset.TryGetProperty("browser_download_url", out JsonElement download) ||
                download.ValueKind != JsonValueKind.String)
                return null;

            string checksum = digest.GetString() ?? string.Empty;
            if (!Regex.IsMatch(checksum, @"^sha256:[0-9a-fA-F]{64}$", RegexOptions.CultureInvariant))
                return null;

            if (!Uri.TryCreate(download.GetString(), UriKind.Absolute, out Uri? url) ||
                url.Scheme != Uri.UriSchemeHttps ||
                !string.Equals(url.Host, "github.com", StringComparison.OrdinalIgnoreCase) ||
                !url.IsDefaultPort || url.UserInfo.Length != 0 ||
                url.Query.Length != 0 || url.Fragment.Length != 0 ||
                !string.Equals(url.AbsolutePath,
                    AssetPrefix + release.Tag + "/" + expectedFileName, StringComparison.Ordinal))
                return null;

            match = new OfficialInstallerAsset(expectedFileName, url, length, checksum[7..].ToUpperInvariant());
        }

        return match;
    }

    /// <summary>
    /// Validates bytes against the asset digest; it does not validate Authenticode.
    /// Pass a stream positioned at the beginning of the complete downloaded file.
    /// </summary>
    public static bool VerifySha256(Stream downloadedFile, OfficialInstallerAsset asset)
    {
        if (downloadedFile is null || !downloadedFile.CanRead)
            return false;
        byte[] actual = SHA256.HashData(downloadedFile);
        byte[] expected = Convert.FromHexString(asset.Sha256);
        return CryptographicOperations.FixedTimeEquals(actual, expected);
    }
}
