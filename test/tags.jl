using OpenType
using OpenType: Tag, find_language_tag, find_script_tag
using Test

@testset "Tags" begin
  t = Tag("FRA ")
  @test isa(t, Tag{4})
  @test convert(Tag, "FRA ") === t
  @test tag"FRA " === t
  @test tag"FRA" !== tag"FRA "
  @test isa(tag"FRA", Tag{3})
  @test_throws "4-character" Tag{4}("FRA")
  @test_throws "ASCII" Tag("FRAα")
  @test uppercase(tag"fr") === tag"FR"
  @test lowercase(tag"FR") === tag"fr"

  @testset "Language tags" begin
    res = tag"FRA "
    @test find_language_tag(tag"FRA ") === res
    @test find_language_tag(tag"FRA") === res
    @test find_language_tag(tag"fra") === res
    @test find_language_tag(tag"fr") === res
    @test find_language_tag(tag"FR") === res

    # "cdo" is a part of the Chinese macrolanguage "zho".
    # "zho" has several typographic languages (e.g. simplified and traditional Chinese), with no canonical choice.
    # Therefore what we get is the last entry in the dictionary that overwrites the previous ones.
    # Applications willing to take a particular typographic language will need to provide the OpenType language tag.
    # TODO: Allow typographic languages to be specified with IETF BCP 47 language tags, e.g. zh-CN (simplified Chinese)
    # and zh-TW (traditional Chinese).
    @test find_language_tag(tag"cdo") == tag"ZHTM"
  end

  @testset "Script tags" begin
    res = tag"latn"
    @test find_script_tag(tag"latn") === res
    @test find_script_tag(tag"Latn") === res
    @test find_script_tag(tag"LaTN") === nothing
    @test_throws MethodError find_script_tag(tag"lat")
  end
end
