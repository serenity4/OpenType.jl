using OpenType: find_primary_script, find_script

@testset "Scripts" begin
  @test find_primary_script(codepoint('c'), [tag"latn"]) == tag"latn"
  @test find_primary_script(codepoint('μ'), [tag"latn"]) == tag"grek"
  # XXX: this doesn't match with the script tag in the OpenType registry 'lao '.
  @test find_primary_script(codepoint('ບ')) == tag"laoo"
  @test find_primary_script(codepoint(',')) == tag"zyyy"
  @test find_primary_script(0x00000300) == tag"zinh"

  find_scripts(chars, recent_tags) = find_script.(Ref(chars), eachindex(chars), Ref(recent_tags))
  @test find_scripts(['c', 'a', ',', 'b'], [tag"latn"]) == [tag"latn", tag"latn", tag"latn", tag"latn"]
  @test find_scripts([',', ';'], [tag"latn"]) == [tag"zyyy", tag"zyyy"]
  @test find_scripts(['a', ',', ';'], [tag"latn"]) == [tag"latn", tag"latn", tag"latn"]
  @test find_scripts([',', ';', 'a'], [tag"latn"]) == [tag"zyyy", tag"zyyy", tag"latn"]
  @test find_scripts(['(', 'a', 'ρ', Char(0x0300), ')'], [tag"latn"]) == [tag"zyyy", tag"latn", tag"grek", tag"grek", tag"grek"]
end;
