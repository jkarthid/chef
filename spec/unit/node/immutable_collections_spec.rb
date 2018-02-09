#
# Author:: Daniel DeLeo (<dan@chef.io>)
# Copyright:: Copyright 2012-2018, Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "spec_helper"
require "chef/node/immutable_collections"

describe Chef::Node::ImmutableMash do

  before do
    @data_in = { "key" =>
                 { "top" => { "second_level" => "some value" },
                   "top_level_2" => %w{array of values},
                   "top_level_3" => [{ "hash_array" => 1, "hash_array_b" => 2 }],
                   "top_level_4" => { "level2" => { "key" => "value" } },
                 },
    }
    @node = Chef::Node.new()
    @node.attributes.default = @data_in
    @immutable_mash = @node["key"]
  end

  it "element references like regular hash" do
    expect(@immutable_mash[:top][:second_level]).to eq("some value")
  end

  it "element references like a regular Mash" do
    expect(@immutable_mash[:top_level_2]).to eq(%w{array of values})
  end

  it "converts Hash-like inputs into ImmutableMash's" do
    expect(@immutable_mash[:top]).to be_a(Chef::Node::ImmutableMash)
  end

  it "converts array inputs into ImmutableArray's" do
    expect(@immutable_mash[:top_level_2]).to be_a(Chef::Node::ImmutableArray)
  end

  it "converts arrays of hashes to ImmutableArray's of ImmutableMashes" do
    expect(@immutable_mash[:top_level_3].first).to be_a(Chef::Node::ImmutableMash)
  end

  it "converts nested hashes to ImmutableMashes" do
    expect(@immutable_mash[:top_level_4]).to be_a(Chef::Node::ImmutableMash)
    expect(@immutable_mash[:top_level_4][:level2]).to be_a(Chef::Node::ImmutableMash)
  end

  # we only ever absorb VividMashes from other precedence levels, which already have
  # been coerced to only have string keys, so we do not need to do that work twice (performance).
  it "does not call convert_value like Mash/VividMash" do
    @node.attributes.default = { test: "foo", "test2" => "bar" }
    expect(@node[:test]).to eql("foo")
    expect(@node["test2"]).to eql("bar")
  end

  describe "to_hash" do
    before do
      @copy = @immutable_mash.to_hash
    end

    it "converts an immutable mash to a new mutable hash" do
      expect(@copy).to be_instance_of(Hash)
    end

    it "converts an immutable nested mash to a new mutable hash" do
      expect(@copy["top_level_4"]["level2"]).to be_instance_of(Hash)
    end

    it "converts an immutable nested array to a new mutable array" do
      expect(@copy["top_level_2"]).to be_instance_of(Array)
    end

    it "should create a mash with the same content" do
      puts @copy.class
      puts @immutable_mash.class
      expect(@immutable_mash).to eq(@copy)
    end

    it "should allow mutation" do
      expect { @copy["m"] = "m" }.not_to raise_error
    end

  end

  [
    :[]=,
    :clear,
    :default=,
    :default_proc=,
    :delete,
    :delete_if,
    :keep_if,
    :merge!,
    :update,
    :reject!,
    :replace,
    :select!,
    :shift,
    :write,
    :write!,
    :unlink,
    :unlink!,
  ].each do |mutator|
    it "doesn't allow mutation via `#{mutator}'" do
      expect { @immutable_mash.send(mutator) }.to raise_error(Chef::Exceptions::ImmutableAttributeModification)
    end
  end

  it "returns a mutable version of itself when duped" do
    mutable = @immutable_mash.dup
    mutable[:new_key] = :value
    expect(mutable[:new_key]).to eq(:value)
  end

end

describe Chef::Node::ImmutableArray do

  before do
    @node = Chef::Node.new()
    @node.attributes.default = { "key" => ["level1", %w{foo bar baz} + Array(1..3) + [nil, true, false, [ "el", 0, nil ] ], { "m" => "m" }] }
    @immutable_array = @node["key"][1]
    @immutable_mash = @node["key"][2]
    @immutable_nested_array = @node["key"]
  end

  ##
  # Note: other behaviors, such as immutibilizing input data, are tested along
  # with ImmutableMash, above
  ###

  [
    :<<,
    :[]=,
    :clear,
    :collect!,
    :compact!,
    :default=,
    :default_proc=,
    :delete,
    :delete_at,
    :delete_if,
    :fill,
    :flatten!,
    :insert,
    :keep_if,
    :map!,
    :merge!,
    :pop,
    :push,
    :update,
    :reject!,
    :reverse!,
    :replace,
    :select!,
    :shift,
    :slice!,
    :sort!,
    :sort_by!,
    :uniq!,
    :unshift,
  ].each do |mutator|
    it "does not allow mutation via `#{mutator}" do
      expect { @immutable_array.send(mutator) }.to raise_error(Chef::Exceptions::ImmutableAttributeModification)
    end
  end

  it "can be duped even if some elements can't" do
    @immutable_array.dup
  end

  it "returns a mutable version of itself when duped" do
    mutable = @immutable_array.dup
    mutable[0] = :value
    expect(mutable[0]).to eq(:value)
  end

  describe "to_a" do
    before do
      @copy = @immutable_nested_array.to_a
    end

    it "converts an immutable array to a new mutable array" do
      expect(@copy).to be_instance_of(Array)
    end

    it "converts an immutable nested array to a new mutable array" do
      expect(@copy[1]).to be_instance_of(Array)
    end

    it "converts an immutable nested mash to a new mutable hash" do
      expect(@copy[2]).to be_instance_of(Hash)
    end

    it "should create an array with the same content" do
      expect(@immutable_nested_array).to eq(@copy)
    end

    it "should allow mutation" do
      expect { @copy << "m" }.not_to raise_error
    end
  end

  describe "#[]" do
    it "works with array slices" do
      expect(@immutable_array[1, 2]).to eql(%w{bar baz})
    end
  end

  describe "uniq" do
    it "works" do
      @node.attributes.default = { "key" => %w{foo bar foo baz bar} }
      expect(@node["key"].uniq).to eql(%w{foo bar baz})
    end
  end
end
