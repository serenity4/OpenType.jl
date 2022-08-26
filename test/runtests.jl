using OpenType
using OpenType: GlyphPointInfo
using GeometryExperiments
using Test

font_file(filename) = joinpath(@__DIR__, "resources", filename * ".ttf")
load_font(filename) = OpenTypeData(font_file(filename))

# ENV["JULIA_DEBUG"] = "OpenType"

data = load_font("juliamono");
data = load_font("aceh-darusalam");
data = load_font("arial");
data = load_font("bodoni-moda");
data = load_font("cherolina");
data = load_font("jet-brains-mono");

@testset "OpenType.jl" begin
    data = load_font("juliamono")
    font = OpenTypeFont(data)

    @testset "Glyphs" begin
        glyph = data.glyf.glyphs[64]
        glyph_header = glyph.header
        @test glyph_header == OpenType.GlyphHeader(1, 55, -15, 526, 732)
        @test glyph.data.end_pts_of_contours == [25]
        glyph_points = [
            GlyphPointInfo((186,-15), false),
            GlyphPointInfo((55,171), false),
            GlyphPointInfo((55,352), true),
            GlyphPointInfo((55,535), false),
            GlyphPointInfo((195,732), false),
            GlyphPointInfo((325,732), true),
            GlyphPointInfo((390,732), false),
            GlyphPointInfo((497,687), false),
            GlyphPointInfo((526,636), true),
            GlyphPointInfo((471,595), true),
            GlyphPointInfo((435,634), false),
            GlyphPointInfo((366,660), false),
            GlyphPointInfo((322,660), true),
            GlyphPointInfo((230,660), false),
            GlyphPointInfo((149,503), false),
            GlyphPointInfo((149,357), true),
            GlyphPointInfo((149,211), false),
            GlyphPointInfo((225,60), false),
            GlyphPointInfo((319,60), true),
            GlyphPointInfo((370,60), false),
            GlyphPointInfo((445,95), false),
            GlyphPointInfo((472,135), true),
            GlyphPointInfo((526,87), true),
            GlyphPointInfo((494,35), false),
            GlyphPointInfo((386,-15), false),
            GlyphPointInfo((318,-15), true),
        ]
        @test OpenType.extract_points(glyph.data) == glyph_points

        @testset "Data extraction" begin
            # Corresponds to data.glyf.glyphs[64] after removing `nothing` elements.
            glyph = font.glyphs[58]
            (; outlines) = glyph
            outline = first(outlines)
            for point in glyph_points
                @test point.coords in outline
            end
            @test first(outline) == Point(55,352)
            for outline in outlines
                @test last(outline) == first(outline)
                @test isodd(length(outline))
                @test all(glyph_header.xmin ≤ point[1] ≤ glyph_header.xmax for point in outline)
                @test all(glyph_header.ymin ≤ point[2] ≤ glyph_header.ymax for point in outline)
            end

            norm_outlines = OpenType.normalize(outlines, glyph_header)
            for norm_outline in norm_outlines
                for point in norm_outline
                    @test all(0 .≤ point .≤ 1)
                end
            end

            curves = OpenType.curves(glyph)
            @test all(length(curve) == 3 for curve in curves)
        end
    end

    @testset "Character to Glyph mapping" begin
        @test font['c'] == font.glyphs[626]
    end

    @testset "Font loading" begin
        for f in ["juliamono", "aceh-darusalam", "arial", "bodoni-moda"]
            @test isa(load_font(f), OpenTypeData)
        end
    end
end;
