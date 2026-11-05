using System.Globalization;

namespace DK.EasyRenamer.Core;

public enum RenameSortField { NaturalName, Name, CreatedUtc, ModifiedUtc, Size }

public static class RenameSelectionSorter
{
    public static IReadOnlyList<RenameSelection> Sort(
        IEnumerable<RenameSelection> items, RenameSortField field, bool descending = false)
    {
        var indexed = items.Select((item, index) =>
        {
            string path = Path.GetFullPath(item.Path);
            // Name sorting only needs the path text. A selection may have been
            // removed since it was added; preview validation handles that.
            FileFingerprint? fp = field is RenameSortField.Name or RenameSortField.NaturalName
                ? null : FileFingerprint.Capture(path);
            // Directory selections may end with a separator. Sort by the actual
            // folder name, while preserving the original selection path.
            return (Item: item, Name: Path.GetFileName(Path.TrimEndingDirectorySeparator(path)), State: fp, OriginalIndex: index);
        });

        IComparer<string> comparer = field switch
        {
            RenameSortField.NaturalName => Comparer<string>.Create(NaturalCompare),
            RenameSortField.Name => StringComparer.OrdinalIgnoreCase,
            _ => StringComparer.OrdinalIgnoreCase
        };

        // OrderByDescending, unlike reversing an ascending result, keeps
        // the original user order when two items have equal sort keys.
        var ordered = field switch
        {
            RenameSortField.CreatedUtc => descending
                ? indexed.OrderByDescending(x => x.State!.CreatedUtc)
                : indexed.OrderBy(x => x.State!.CreatedUtc),
            RenameSortField.ModifiedUtc => descending
                ? indexed.OrderByDescending(x => x.State!.LastWriteUtc)
                : indexed.OrderBy(x => x.State!.LastWriteUtc),
            RenameSortField.Size => descending
                ? indexed.OrderByDescending(x => x.State!.Length)
                : indexed.OrderBy(x => x.State!.Length),
            _ => descending
                ? indexed.OrderByDescending(x => x.Name, comparer)
                : indexed.OrderBy(x => x.Name, comparer)
        };
        return ordered.Select(x => x.Item).ToArray();
    }

    public static int NaturalCompare(string? left, string? right)
    {
        left ??= "";
        right ??= "";
        int a = 0, b = 0;
        while (a < left.Length && b < right.Length)
        {
            if (char.IsAsciiDigit(left[a]) && char.IsAsciiDigit(right[b]))
            {
                int aStart = a, bStart = b;
                while (a < left.Length && char.IsAsciiDigit(left[a])) a++;
                while (b < right.Length && char.IsAsciiDigit(right[b])) b++;
                int aSignificant = aStart, bSignificant = bStart;
                while (aSignificant < a && left[aSignificant] == '0') aSignificant++;
                while (bSignificant < b && right[bSignificant] == '0') bSignificant++;
                int aLength = a - aSignificant, bLength = b - bSignificant;
                if (aLength != bLength) return aLength.CompareTo(bLength);
                int digitCompare = string.CompareOrdinal(left, aSignificant, right,
                    bSignificant, aLength);
                if (digitCompare != 0) return digitCompare;
                int zerosTie = (a - aStart).CompareTo(b - bStart);
                if (zerosTie != 0) return zerosTie;
            }
            else
            {
                int difference = char.ToUpperInvariant(left[a]).CompareTo(char.ToUpperInvariant(right[b]));
                if (difference != 0) return difference;
                a++;
                b++;
            }
        }
        return (left.Length - a).CompareTo(right.Length - b);
    }
}
