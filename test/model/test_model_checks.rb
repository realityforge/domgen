require File.expand_path('../../helper', __FILE__)
require 'domgen'

class Domgen::TestModelChecks < Domgen::TestCase
  def test_rejects_abstract_exception_on_service_method
    error = assert_raises(RuntimeError) do
      new_repository do |repository|
        repository.data_module(:Core) do |data_module|
          data_module.exception(:Failure, :abstract => true)
          data_module.service(:ExampleService) do |service|
            service.method(:Perform) { |method| method.exception(:Failure) }
          end
        end
      end
    end

    assert_equal "Model Check 'ServiceExceptions' failed due to: Service method 'Core.ExampleService#Perform' exposes non-leaf exception 'Core.Failure'.",
                 error.message
  end

  def test_rejects_exception_with_subtypes_on_service_method
    error = assert_raises(RuntimeError) do
      new_repository do |repository|
        repository.data_module(:Core) do |data_module|
          data_module.exception(:Failure, :final => false)
          data_module.exception(:SpecificFailure, :extends => :Failure)
          data_module.service(:ExampleService) do |service|
            service.method(:Perform) { |method| method.exception(:Failure) }
          end
        end
      end
    end

    assert_equal "Model Check 'ServiceExceptions' failed due to: Service method 'Core.ExampleService#Perform' exposes non-leaf exception 'Core.Failure'.",
                 error.message
  end

  def test_accepts_leaf_service_exception_and_internal_abstract_family
    repository = new_repository do |r|
      r.data_module(:Core) do |data_module|
        data_module.exception(:InternalFailure, :abstract => true)
        data_module.exception(:SpecificInternalFailure, :extends => :InternalFailure)
        data_module.exception(:ServiceFailure)
        data_module.service(:ExampleService) do |service|
          service.method(:Perform) { |method| method.exception(:ServiceFailure) }
        end
      end
    end

    assert_equal 'Core.ServiceFailure!',
                 repository.data_module_by_name(:Core).service_by_name(:ExampleService).method_by_name(:Perform).exceptions.first.qualified_name
  end

  private

  def new_repository(&block)
    @repository_index ||= 0
    @repository_index += 1
    Domgen::Repository.new("ModelChecks#{object_id}#{@repository_index}".to_sym, nil, {}, &block)
  end
end
