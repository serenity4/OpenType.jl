using OpenType
using OpenType: find_language_tag, find_script_tag
using Test

@testset "Tags" begin
  @testset "Language tags" begin
    res = tag"FRA "
    @test find_language_tag(tag"FRA ") === res
    @test find_language_tag(tag"FRA") === res
    @test find_language_tag(tag"fra") === res
    @test find_language_tag(tag"fr") === res
    @test find_language_tag(tag"FR") === res

    # "cdo" is part of the Chinese macrolanguage "zho".
    # "zho" has several typographic languages in OpenType (e.g. simplified and traditional Chinese), with no canonical choice.
    # Therefore what we get is the last entry in the dictionary that overwrites the previous ones.
    # Applications willing to take a particular typographic language will need to provide the OpenType language tag at the moment.
    # TODO: Allow typographic languages to be specified with IETF BCP 47 language tags, e.g. zh-CN (Chinese, mainland China - often used to denote simplified Chinese)
    # and zh-TW (Chinese, Taiwan - often used to denote traditional Chinese).
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
