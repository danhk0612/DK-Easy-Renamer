using DK.EasyRenamer.Core;
using Xunit;

namespace DK.EasyRenamer.Core.Tests;

public sealed class ProjectInfoTests
{
    [Fact]
    public void Product_name_is_stable()
    {
        Assert.Equal("DK Easy Renamer", ProjectInfo.ProductName);
    }

    [Fact]
    public void Primary_brand_color_matches_design_contract()
    {
        Assert.Equal("#2D7BC6", ProjectInfo.AccentColor);
    }
}
