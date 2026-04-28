require "spec_helper"

module Wasmtime
  module Component
    RSpec.describe Linker do
      let(:linker) { Linker.new(engine) }

      it "disallows linker reentrance" do
        linker.root do
          expect { linker.root }.to raise_error(Wasmtime::Error, /reentrant/)
        end
      end

      it "disallows linker instance reentrance" do
        linker.instance("foo") do |foo|
          foo.instance("bar") do |_|
            expect { foo.instance("bar") {} }.to raise_error(Wasmtime::Error, /reentrant/)
            expect { foo.module("bar", Module.new(engine, wat)) {} }.to raise_error(Wasmtime::Error, /reentrant/)
          end
        end
      end

      it "disallows using LinkerInstance outside its block" do
        leaked_instance = nil
        linker.root { |root| leaked_instance = root }
        expect { leaked_instance.instance("foo") {} }
          .to raise_error(Wasmtime::Error, /LinkerInstance went out of scope/)
      end

      describe "#instantiate" do
        it "returns a Component::Instance" do
          component = Component.new(engine, "(component)")
          store = Store.new(engine)
          expect(linker.instantiate(store, component))
            .to be_instance_of(Wasmtime::Component::Instance)
        end
      end

      describe "LinkerInstance#func_new" do
        let(:t) { Type }

        context "simple host functions" do
          it "defines a function with primitives" do
            linker.root do |root|
              root.func_new("greet", [t.string], [t.string]) do |name|
                "Hello, #{name}!"
              end
            end

            expect(linker).to be_a(Linker)
          end

          it "defines a function with multiple params" do
            linker.root do |root|
              root.func_new("add", [t.u32, t.u32], [t.u32]) do |a, b|
                a + b
              end
            end

            expect(linker).to be_a(Linker)
          end

          it "defines a function with no params" do
            linker.root do |root|
              root.func_new("get-constant", [], [t.u32]) do
                42
              end
            end

            expect(linker).to be_a(Linker)
          end

          it "defines a function with no results" do
            linker.root do |root|
              root.func_new("log", [t.string], []) do |_msg|
                nil
              end
            end

            expect(linker).to be_a(Linker)
          end
        end

        context "complex types" do
          it "defines a function with record types" do
            point_type = t.record("x" => t.s32, "y" => t.s32)

            linker.root do |root|
              root.func_new("make-point", [t.s32, t.s32], [point_type]) do |x, y|
                {"x" => x, "y" => y}
              end
            end

            expect(linker).to be_a(Linker)
          end

          it "defines a function with list types" do
            linker.root do |root|
              root.func_new("sum-list", [t.list(t.s32)], [t.s32]) do |numbers|
                numbers.sum
              end
            end

            expect(linker).to be_a(Linker)
          end

          it "defines a function with option types" do
            linker.root do |root|
              root.func_new("maybe-double", [t.option(t.u32)], [t.option(t.u32)]) do |n|
                n.nil? ? nil : n * 2
              end
            end

            expect(linker).to be_a(Linker)
          end

          it "defines a function with result types" do
            linker.root do |root|
              root.func_new(
                "safe-divide",
                [t.u32, t.u32],
                [t.result(t.u32, t.string)]
              ) do |a, b|
                if b == 0
                  Result.error("division by zero")
                else
                  Result.ok(a / b)
                end
              end
            end

            expect(linker).to be_a(Linker)
          end
        end

        context "nested instances" do
          it "defines functions in nested instances" do
            linker.instance("math") do |math|
              math.func_new("add", [t.u32, t.u32], [t.u32]) do |a, b|
                a + b
              end
            end

            expect(linker).to be_a(Linker)
          end
        end

        context "error cases" do
          it "requires a block" do
            expect {
              linker.root do |root|
                root.func_new("no-block", [], [t.u32])
              end
            }.to raise_error(ArgumentError, /no block given/)
          end
        end
      end
    end
  end
end
