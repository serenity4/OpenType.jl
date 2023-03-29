using OpenType: find_primary_script, find_script

@testset "Scripts" begin
  sc = find_primary_script(codepoint('c'), [tag"latn"])
  @test sc == tag"latn"
  sc = find_primary_script(codepoint('μ'), [tag"latn"])
  @test sc == tag"grek"
  sc = find_primary_script(codepoint('ບ'), [tag"latn"])
  # XXX: this doesn't match with the script tag in the OpenType registry 'lao '.
  @test sc == tag"laoo"
end
