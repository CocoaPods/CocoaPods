module Pod

  # Provides basic support for Dependency Injection in a class.
  #
  module DependencyInjection

    # Declares a dependency in another class specifying a default.  The class
    # implementing this method should should initialize the dependency
    # accessing this property.
    #
    # @param  [Symbol] name
    #         the name of the dependency.
    #
    # @param  [Class] default_class
    #         the default class to use for the dependency.
    #
    # @return [void]
    #
    def dependency(name, default_class)
      singleton_class.class_eval do
        attr_writer name
        define_method(name) { instance_variable_get("@#{name}") || default_class }
      end
    end

  end
end
