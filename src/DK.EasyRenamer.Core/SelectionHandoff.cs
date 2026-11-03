using System.Buffers.Binary;
using System.Text;

namespace DK.EasyRenamer.Core;

// Binary handoff for the T01 Explorer selection probe; never performs a rename.
public static class SelectionHandoff
{
    private static readonly byte[] Magic = [(byte)'D', (byte)'K', (byte)'R', (byte)'1'];
    public const int MaxItems = 10_000;
    public const int MaxPathCharacters = 32_767;

    public static string[] Read(Stream input)
    {
        ArgumentNullException.ThrowIfNull(input);
        Span<byte> word = stackalloc byte[4];
        input.ReadExactly(word);
        if (!word.SequenceEqual(Magic))
            throw new InvalidDataException("Invalid selection packet magic.");

        input.ReadExactly(word);
        uint count = BinaryPrimitives.ReadUInt32LittleEndian(word);
        if (count == 0 || count > MaxItems)
            throw new InvalidDataException("Invalid selection count.");

        var paths = new string[checked((int)count)];
        for (int i = 0; i < paths.Length; i++)
        {
            input.ReadExactly(word);
            uint length = BinaryPrimitives.ReadUInt32LittleEndian(word);
            if (length == 0 || length > MaxPathCharacters)
                throw new InvalidDataException("Invalid path length.");
            byte[] bytes = new byte[checked((int)length * 2)];
            input.ReadExactly(bytes);
            string path = Encoding.Unicode.GetString(bytes);
            if (path.IndexOf('\0') >= 0 || !Path.IsPathFullyQualified(path))
                throw new InvalidDataException("Invalid absolute path.");
            paths[i] = path;
        }
        if (input.ReadByte() != -1)
            throw new InvalidDataException("Unexpected trailing packet bytes.");
        return paths;
    }

    // Test fixture writer: exactly the same little-endian UTF-16LE packet as C++.
    public static void Write(Stream output, IReadOnlyList<string> paths)
    {
        ArgumentNullException.ThrowIfNull(output);
        ArgumentNullException.ThrowIfNull(paths);
        if (paths.Count is 0 or > MaxItems)
            throw new ArgumentOutOfRangeException(nameof(paths));
        output.Write(Magic);
        Span<byte> word = stackalloc byte[4];
        BinaryPrimitives.WriteUInt32LittleEndian(word, (uint)paths.Count);
        output.Write(word);
        foreach (string path in paths)
        {
            if (string.IsNullOrEmpty(path) || path.Length > MaxPathCharacters ||
                path.IndexOf('\0') >= 0 || !Path.IsPathFullyQualified(path))
                throw new ArgumentException("Requires fully qualified Windows paths.", nameof(paths));
            BinaryPrimitives.WriteUInt32LittleEndian(word, (uint)path.Length);
            output.Write(word);
            output.Write(Encoding.Unicode.GetBytes(path));
        }
    }
}
