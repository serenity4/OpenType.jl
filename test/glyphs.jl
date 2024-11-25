using OpenType
using OpenType: OpenTypeData, GlyphPointInfo, GlyphHeader, extract_points
using StaticArrays
using LinearAlgebra

@testset "Glyphs" begin
  data = load_font("juliamono")
  font = OpenTypeFont(data)

  @testset "Glyphs" begin
    glyph = data.glyf.glyphs[64]
    glyph_header = glyph.header
    @test glyph_header == GlyphHeader(1, 55, -15, 526, 732)
    @test glyph.data.end_pts_of_contours == [25]
    glyph_points = [
      GlyphPointInfo((186, -15), false),
      GlyphPointInfo((55, 171), false),
      GlyphPointInfo((55, 352), true),
      GlyphPointInfo((55, 535), false),
      GlyphPointInfo((195, 732), false),
      GlyphPointInfo((325, 732), true),
      GlyphPointInfo((390, 732), false),
      GlyphPointInfo((497, 687), false),
      GlyphPointInfo((526, 636), true),
      GlyphPointInfo((471, 595), true),
      GlyphPointInfo((435, 634), false),
      GlyphPointInfo((366, 660), false),
      GlyphPointInfo((322, 660), true),
      GlyphPointInfo((230, 660), false),
      GlyphPointInfo((149, 503), false),
      GlyphPointInfo((149, 357), true),
      GlyphPointInfo((149, 211), false),
      GlyphPointInfo((225, 60), false),
      GlyphPointInfo((319, 60), true),
      GlyphPointInfo((370, 60), false),
      GlyphPointInfo((445, 95), false),
      GlyphPointInfo((472, 135), true),
      GlyphPointInfo((526, 87), true),
      GlyphPointInfo((494, 35), false),
      GlyphPointInfo((386, -15), false),
      GlyphPointInfo((318, -15), true),
    ]
    @test extract_points(glyph.data) == glyph_points

    @testset "Data extraction" begin
      glyph = font.glyphs[64]
      (; outlines) = glyph
      outline = first(outlines)
      for point in glyph_points
        @test point.coords in outline
      end

      for outline in outlines
        @test last(outline) == first(outline)
        @test isodd(length(outline))
        @test all(glyph_header.xmin ≤ point[1] ≤ glyph_header.xmax for point in outline)
        @test all(glyph_header.ymin ≤ point[2] ≤ glyph_header.ymax for point in outline)
      end

      # Coordinate system is in (integer) font units.
      curves = OpenType.curves(glyph)
      @test isa(curves, Vector{Vec{3,Vec2}})
      @test all(length(curve) == 3 for curve in curves)
      mi, ma = extrema(maximum.(broadcast.(norm, curves)))
      @test 300 < mi < 400 && 800 < ma < 900
    end
  end

  @testset "Character to Glyph mapping" begin
    @test font['c'] == font.glyphs[626]
  end
end
