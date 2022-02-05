@serializable struct MaximumProfile
    version::VERSION16DOT16
    nglyphs::UInt16
    max_points::UInt16
    max_contours::UInt16
    max_composite_points::UInt16
    max_composite_contours::UInt16
    max_zones::UInt16
    max_twilight_points::UInt16
    max_storage::UInt16
    max_function_defs::UInt16
    max_instruction_defs::UInt16
    max_stack_elements::UInt16
    max_size_of_instructions::UInt16
    max_component_elements::UInt16
    max_component_depth::UInt16
end
