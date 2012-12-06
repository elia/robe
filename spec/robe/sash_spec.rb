require 'spec_helper'
require 'support/mocks'
require 'robe/sash'

describe Robe::Sash do
  klass = described_class

  context "#modules" do
    it "returns module names" do
      mock_space = MockVisor.new(*%w(A B C).map { |n| OpenStruct.new(name: n) })
      expect(klass.new(mock_space).modules).to eq %w(A B C)
    end
  end

  context "#class_locations" do
    it "shows location when class has methods" do
      k = klass.new(double(resolve_context: Class.new { def foo; end }))
      expect(k.class_locations(nil, nil)).to eq([__FILE__])
    end

    it "shows no location for class without methods" do
      k = klass.new(double(resolve_context: Class.new))
      expect(k.class_locations(nil, nil)).to be_empty
    end
  end

  context "#targets" do
    let(:m) do
      Module.new do
        def self.name
          "M"
        end
        def foo; end
        private
        def baz; end
        class << self
          def oom; end
          private
          def tee; end
        end
      end
    end
    let(:k) { klass.new(double(resolve_const: m)) }
    subject { k.targets(nil)[1..-1] }

    specify { expect(k.targets(nil)[0]).to eq("M") }

    it { should include(["M", :instance, :foo, __FILE__, __LINE__ - 15]) }
    it { should include(["M", :instance, :baz, __FILE__, __LINE__ - 14]) }
    it { should include(["M", :module, :oom, __FILE__, __LINE__ - 13]) }
    it { expect(subject.select { |(_, _, m)| m == :tee }).to be_empty }
  end

  context "#find_method" do
    let(:k) { klass.new }

    it { expect(k.find_method(String, :instance, :gsub).name).to eq(:gsub) }
    it { expect(k.find_method(String, :module, :freeze).name).to eq(:freeze) }
  end

  context "#method_info" do
    let(:k) { klass.new }

    it { expect(k.method_info(String, :instance, :gsub))
         .to eq(["String", :instance, :gsub]) }

    it "includes method location" do
      m = Module.new { def foo; end }
      expect(k.method_info(m, :instance, :foo))
        .to eq([nil, :instance, :foo, __FILE__, __LINE__ - 2])
    end

    it "subtitutes anonymous module with containing class name" do
      c = Class.new do
        Module.new do
          def foo; end
        end.tap { |m| include m }
      end
      expect(k.method_info(c, :instance, :foo))
        .to eq([c.inspect, :instance, :foo, __FILE__, anything])
    end
  end

  context "#method_targets" do
    it "returns empty array when not found" do
      k = klass.new(MockVisor.new)
      k.visor.should_receive(:resolve_context).with("b", "c").and_return(nil)
      expect(k.method_targets("a", "b", "c", true, nil, nil)).to be_empty
    end

    context "examples" do
      let(:k) { klass.new }

      it "returns class method candidate" do
        expect(k.method_targets("open", "File", nil, nil, nil, nil))
          .to eq([["IO", :module, :open]])
      end

      it "returns the constructor" do
        expect(k.method_targets("initialize", "Object", nil, nil, nil, nil))
          .to include(["Class", :module, :initialize])
      end

      it "doesn't return overridden method" do
        expect(k.method_targets("to_s", "Hash", nil, true, nil, nil))
          .to eq([["Hash", :instance, :to_s]])
      end

      context "unknown target" do
        it "returns String method candidate" do
          expect(k.method_targets("split", "s", nil, true, nil, nil))
            .to include(["String", :instance, :split])
        end

        it "does not return wrong candidates" do
          candidates = k.method_targets("split", "s", nil, true, nil, nil)
          expect(candidates).to be_all { |c| c[2] == :split }
        end
      end

      it "returns no candidates for target when conservative" do
        expect(k.method_targets("split", nil, nil, true, nil, true))
          .to be_empty
      end

      it "returns single instance method from superclass" do
        expect(k.method_targets("map", nil, "Array", true, true, nil))
          .to eq([["Enumerable", :instance, :map]])
      end

      it "returns single method from target class" do
        expect(k.method_targets("map", nil, "Array", true, nil, nil))
          .to eq([["Array", :instance, :map]])
      end

      it "checks private Kernel methods when no primary candidates" do
        k = klass.new(MockVisor.new)
        expect(k.method_targets("puts", nil, nil, true, nil, nil))
          .to eq([["Kernel", :instance, :puts]])
      end

      it "sorts results list" do
        extend ScannerHelper

        a = named_module("A", "a", "b", "c", "d")
        b = named_module("A::B", "a", "b", "c", "d")
        c = new_module("a", "b", "c", "d")
        k = klass.new(MockVisor.new(*[b, c, a].shuffle))
        expect(k.method_targets("a", nil, nil, true, nil, nil).map { |(m)| m })
          .to eq(["A", "A::B", nil])
      end
    end
  end

  context "#complete_method" do
    let(:k) { klass.new }

    it "completes instance methods" do
      expect(k.complete_method("gs", nil, nil, true))
        .to include(:gsub, :gsub!)
    end

    context "class methods" do
      let(:k) { klass.new(MockVisor.new(Class)) }

      it "completes public" do
        expect(k.complete_method("su", nil, nil, nil)).to include(:superclass)
      end

      it "no private methods with explicit target" do
        expect(k.complete_method("attr", "Object", nil, nil))
          .not_to include(:attr_reader)
      end

      it "no private methods with no target at all" do
        expect(k.complete_method("attr", "Object", nil, nil))
          .not_to include(:attr_reader)
      end

      it "completes private methods with implicit target" do
        expect(k.complete_method("attr", nil, "Object", nil))
          .to include(:attr_reader, :attr_writer)
      end
    end
  end

  context "#complete_const" do
    let(:v) { double("visor")}
    let(:k) { klass.new(v) }
    let(:m) do
      Module.new do
        def self.name
          "Test"
        end

        self::ACONST = 1

        module self::AMOD; end
        module self::BMOD
          def self.name
            "BMOD"
          end

          module self::C; end
        end

        class self::ACLS; end
      end
    end

    context "sandboxed" do
      before(:each) do
        v.should_receive(:resolve_const).with("Test").and_return(m)
      end

      it "completes all constants" do
        expect(k.complete_const("Test::A"))
          .to eq(%w(Test::ACONST Test::AMOD Test::ACLS))
      end

      it "requires names to begin with prefix" do
        expect(k.complete_const("Test::MOD")).to be_empty
      end
    end

    it "completes with bigger nesting" do
      v.should_receive(:resolve_const).with("Test::BMOD").and_return(m::BMOD)
      expect(k.complete_const("Test::BMOD::C")).to eq(["BMOD::C"])
    end

    it "completes global constants" do
      expect(k.complete_const("Ob")).to include("Object", "ObjectSpace")
    end
  end
end