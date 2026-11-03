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
            FileFingerprint fp = FileFingerprint.Capture(path);
            return (Item: item, Name: Path.GetFileName(path), State: fp, OriginalIndex: index);
        });

        var comparer = field switch
        {
            RenameSortField.NaturalName => Comparer<string>.Create(NaturalCompare),
            RenameSortField.Name => StringComparer.OrdinalIgnoreCase,
            _ => StringComparer.OrdinalIgnoreCase
        };

        IEnumerable<RenameSelection> ordered;
        switch (field)
        {
            case RenameSortField.CreatedUtc:
                ordered = indexed.OrderBy(x => x.State.CreatedUtc).Select(x => x.Item);
                break;
            case RenameSortField.ModifiedUtc:
                ordered = indexed.OrderBy(x => x.State.LastWriteUtc).Select(x => x.Item);
                break;
            case RenameSortField.Size:
                ordered = indexed.OrderBy(x => x.State.Length).Select(x => x.Item);
                break;
            default:
                ordered = indexed.OrderBy(x => x.Name, comparer).Select(x => x.Item);
                break;
        }
        // Stable sort preserves original selection order for ties.
        return (descending ? ordered.Reverse() : ordered).Select(x => x.Item).ToArray();
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
