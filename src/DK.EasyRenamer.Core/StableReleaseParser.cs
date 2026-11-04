using System.Text.Json;
using System.Text.RegularExpressions;

namespace DK.EasyRenamer.Core;

/// <summary>
/// The official GitHub latest stable release is an update *notice*, never a command to execute.
/// This type intentionally exposes only the official, validated release page link.
/// </summary>
public sealed record StableRelease(Version Version, string Tag, Uri ReleasePage);

public static class StableReleaseParser
{
    private const string ReleasePath = "/danhk0612/DK-Easy-Renamer/releases/tag/";

    public static StableRelease? ParseLatest(string json)
    {
        using JsonDocument doc = JsonDocument.Parse(json);
        JsonElement root = doc.RootElement;
        if (root.ValueKind != JsonValueKind.Object)
            return null;

        if (root.TryGetProperty("draft", out var draft) &&
            draft.ValueKind == JsonValueKind.True)
            return null;
        if (root.TryGetProperty("prerelease", out var prerelease) &&
            prerelease.ValueKind == JsonValueKind.True)
            return null;
        if (!root.TryGetProperty("tag_name", out var tagField) ||
            tagField.ValueKind != JsonValueKind.String ||
            !root.TryGetProperty("html_url", out var urlField) ||
            urlField.ValueKind != JsonValueKind.String)
            return null;

        string rawTag = tagField.GetString() ?? "";
        string versionText = rawTag.StartsWith("v", StringComparison.OrdinalIgnoreCase)
            ? rawTag[1..] : rawTag;
        if (!Regex.IsMatch(versionText, @"^\d+\.\d+\.\d+$",
            RegexOptions.CultureInvariant) ||
            !Version.TryParse(versionText, out Version? version))
            return null;

        if (!Uri.TryCreate(urlField.GetString(), UriKind.Absolute, out Uri? url) ||
            url.Scheme != Uri.UriSchemeHttps ||
            !string.Equals(url.Host, "github.com", StringComparison.OrdinalIgnoreCase) ||
            !url.IsDefaultPort ||
            url.UserInfo.Length != 0 ||
            url.Query.Length != 0 || url.Fragment.Length != 0 ||
            !string.Equals(url.AbsolutePath, ReleasePath + rawTag, StringComparison.Ordinal))
            return null;

        return new StableRelease(version, rawTag, url);
    }

    public static bool HasUpdate(StableRelease latest, Version installed) =>
        latest.Version.CompareTo(installed) > 0;
}
