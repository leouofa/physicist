# frozen_string_literal: true

require "test_helper"
require "ostruct"

class Llm::JsonResponseParserTest < ActiveSupport::TestCase
  test "extract_list prefers response.parsed when present" do
    response = OpenStruct.new(parsed: { "subatomic_particles" => [ { "name" => "Up" } ] }, content: "ignored")
    assert_equal [ { "name" => "Up" } ], Llm::JsonResponseParser.extract_list(response, key: "subatomic_particles")
  end

  test "extract_list strips think tags and markdown fences" do
    response = OpenStruct.new(
      parsed: nil,
      content: <<~TEXT
        <think>Thinking about elementary particles...</think>
        ```json
        { "subatomic_particles": [{ "name": "Down", "themes": ["quark"] }] }
        ```
      TEXT
    )

    assert_equal [ { "name" => "Down", "themes" => [ "quark" ] } ],
                 Llm::JsonResponseParser.extract_list(response, key: "subatomic_particles")
  end

  test "extract_list falls back to embedded JSON and returns empty array for invalid text" do
    embedded_array = OpenStruct.new(parsed: nil, content: "Here is the list: [{\"name\":\"Electron\"}] Hope that helps!")
    assert_equal [ { "name" => "Electron" } ], Llm::JsonResponseParser.extract_list(embedded_array, key: "subatomic_particles")

    embedded_object = OpenStruct.new(parsed: nil, content: "[Note] {\"subatomic_particles\":[{\"name\":\"Muon\"}]} Done.")
    assert_equal [ { "name" => "Muon" } ], Llm::JsonResponseParser.extract_list(embedded_object, key: "subatomic_particles")

    invalid = OpenStruct.new(parsed: nil, content: "Not JSON at all")
    assert_equal [], Llm::JsonResponseParser.extract_list(invalid, key: "subatomic_particles")
  end

  test "extract_hash parses flat JSON objects and unwraps optional nested key" do
    flat = OpenStruct.new(
      parsed: nil,
      content: <<~TEXT
        <think>Analyzing physics themes...</think>
        ```json
        {
          "Gauge Symmetry Group": "Invariance under local Lie group phase transformations.",
          "Color Confinement": "Quarks and gluons cannot be isolated at energy scales below QCD scale."
        }
        ```
      TEXT
    )

    assert_equal(
      {
        "Gauge Symmetry Group" => "Invariance under local Lie group phase transformations.",
        "Color Confinement" => "Quarks and gluons cannot be isolated at energy scales below QCD scale."
      },
      Llm::JsonResponseParser.extract_hash(flat, key: "themes")
    )

    wrapped = OpenStruct.new(
      parsed: { "themes" => { "Sovereignty" => "Constitutional governance." } },
      content: "ignored"
    )
    assert_equal({ "Sovereignty" => "Constitutional governance." }, Llm::JsonResponseParser.extract_hash(wrapped, key: "themes"))

    invalid = OpenStruct.new(parsed: nil, content: "No JSON object here")
    assert_equal({}, Llm::JsonResponseParser.extract_hash(invalid, key: "themes"))
  end
end
