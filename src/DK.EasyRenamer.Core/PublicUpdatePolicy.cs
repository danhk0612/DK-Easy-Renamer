using System.Text.RegularExpressions;

namespace DK.EasyRenamer.Core;

/// <summary>
/// Release activation policy. There is deliberately no public signer configured yet.
/// Supplying an approved publisher requires a separately reviewed release decision;
/// local development signatures and unsigned APP-ONLY installers never qualify.
/// </summary>
public static class PublicUpdatePolicy
{
    // DO NOT populate these from release JSON, downloaded files, or user input.
    // Set only after public publisher identity and Windows 11 migration are approved.
    private const string ApprovedSubject = "";
    private const string ApprovedThumbprint = "";

    public static string InstallerFileName(Version version) =>
        $"DK-Easy-Renamer-{version.ToString(3)}-x64-RELEASE.exe";

    public static OfficialInstallerAsset? FindNewerInstaller(string latestReleaseJson, Version installed)
    {
        StableRelease? release = StableReleaseParser.ParseLatest(latestReleaseJson);
        return release is not null && StableReleaseParser.HasUpdate(release, installed)
            ? OfficialInstallerAssetVerifier.Find(latestReleaseJson, InstallerFileName(release.Version))
            : null;
    }

    public static bool TryGetApprovedPublisher(out PublicUpdatePublisher? publisher)
    {
        publisher = null;
        if (string.IsNullOrWhiteSpace(ApprovedSubject) ||
            !Regex.IsMatch(ApprovedThumbprint, @"^[0-9a-fA-F]{40}$",
                RegexOptions.CultureInvariant) ||
            string.Equals(ApprovedSubject, "CN=DK Easy Renamer Development",
                StringComparison.OrdinalIgnoreCase))
            return false;

        publisher = new PublicUpdatePublisher(ApprovedSubject, ApprovedThumbprint.ToUpperInvariant());
        return true;
    }
}

public sealed record PublicUpdatePublisher(string Subject, string Thumbprint);
