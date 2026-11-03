using DK.EasyRenamer.Core;
using Xunit;

namespace DK.EasyRenamer.Core.Tests;

public sealed class SelectionHandoffTests
{
    [Fact]
    public void RoundTripPreservesOrderUnicodeAndUnc()
    {
        string[] names =
        [
            @"C:\여행 자료\IMG 002.png",
            @"\\server\공유\폴더\파일.txt",
            @"D:\file10.jpg",
            @"D:\file2.jpg",
            @"C:\test\日本語\파일.txt"
        ];
        using var stream = new MemoryStream();
        SelectionHandoff.Write(stream, names);
        stream.Position = 0;
        Assert.Equal(names, SelectionHandoff.Read(stream));
    }

    [Fact]
    public void InvalidHeaderFails()
    {
        using var stream = new MemoryStream([0, 0, 0, 0, 1, 0, 0, 0]);
        Assert.Throws<InvalidDataException>(() => SelectionHandoff.Read(stream));
    }

    [Fact]
    public void EmptySelectionFails()
    {
        using var stream = new MemoryStream();
        Assert.Throws<ArgumentOutOfRangeException>(() => SelectionHandoff.Write(stream, []));
    }

    [Fact]
    public void TruncatedPacketFails()
    {
        using var stream = new MemoryStream();
        SelectionHandoff.Write(stream, [@"C:\temp\one.txt"]);
        using var truncated = new MemoryStream(stream.ToArray()[..^1]);
        Assert.Throws<EndOfStreamException>(() => SelectionHandoff.Read(truncated));
    }

    [Fact]
    public void RelativePathFails()
    {
        using var stream = new MemoryStream();
        Assert.Throws<ArgumentException>(() => SelectionHandoff.Write(stream, ["file.txt"]));
    }
}
