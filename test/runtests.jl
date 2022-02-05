using OpenType
using OpenType: HorizontalMetric, VerticalMetric
using GeometryExperiments
using Test

const arial = joinpath(@__DIR__, "resources", "arial.ttf")
const juliamono = joinpath(@__DIR__, "resources", "juliamono-regular.ttf")
const bodoni_moda = joinpath(@__DIR__, "resources", "bodoni-moda.ttf")

@time data = OpenTypeData(juliamono);
@time data = OpenTypeData(arial);
data = OpenTypeData(bodoni_moda)

@testset "OpenType.jl" begin
    data = OpenTypeData(juliamono)
    glyph = data.glyphs[64]
    @test glyph.header == GlyphHeader(1, 55, -15, 526, 732)
    @test glyph.data.contour_indices == [26]
    glyph_points = [
        GlyphPoint((186,-15), false),
        GlyphPoint((55,171), false),
        GlyphPoint((55,352), true),
        GlyphPoint((55,535), false),
        GlyphPoint((195,732), false),
        GlyphPoint((325,732), true),
        GlyphPoint((390,732), false),
        GlyphPoint((497,687), false),
        GlyphPoint((526,636), true),
        GlyphPoint((471,595), true),
        GlyphPoint((435,634), false),
        GlyphPoint((366,660), false),
        GlyphPoint((322,660), true),
        GlyphPoint((230,660), false),
        GlyphPoint((149,503), false),
        GlyphPoint((149,357), true),
        GlyphPoint((149,211), false),
        GlyphPoint((225,60), false),
        GlyphPoint((319,60), true),
        GlyphPoint((370,60), false),
        GlyphPoint((445,95), false),
        GlyphPoint((472,135), true),
        GlyphPoint((526,87), true),
        GlyphPoint((494,35), false),
        GlyphPoint((386,-15), false),
        GlyphPoint((318,-15), true),
    ]
    @test glyph.data.points == glyph_points

    @testset "Data extraction" begin
        curves = uncompress(glyph)
        curve = first(curves)
        for point in glyph_points
            @test point.coords in curve
        end
        @test first(curve) == Point(55,352)
        for c in curves
            @test last(c) == first(c)
            @test isodd(length(c))
            for (x, y) in c
                @test glyph.header.xmin ≤ minimum(x)
                @test glyph.header.ymin ≤ minimum(y)
                @test glyph.header.xmax ≥ maximum(x)
                @test glyph.header.ymax ≥ maximum(y)
            end
        end

        ncurves = normalize(curves, glyph)
        for ncurve in ncurves
            for point in ncurve
                @test all(0 .≤ point .≤ 1)
            end
        end

        curves = OpenType.curves(glyph)
        @test all(==(3), length.(curves))
    end

    @testset "Character to Glyph mapping" begin
        @test data['c'] == data.glyphs[626]
    end

    @testset "Metrics" begin
        @test data.hhea.nhmetrics == 8910
        @test data.vhea.nvmetrics == 4575

        @test first(data.hmtx.metrics) == HorizontalMetric(595, 162)
        @test last(data.hmtx.metrics) == HorizontalMetric(600, 0)

        @test first(data.vmtx.metrics) == VerticalMetric(1140, 328)
        @test last(data.vmtx.metrics) == VerticalMetric(1140, 581)
    end
end
