module Identity
  class ExconInstrumentor
    attr_accessor :events

    def initialize(extra_attrs={})
      @extra_attrs = extra_attrs
    end

    def instrument(name, params={}, &block)
      attrs = { host: params[:host], path: params[:path],
        method: params[:method], expects: params[:expects],
        status: params[:status] }
      attrs.merge!(@extra_attrs)
      Slides.log(name, attrs) { block.call if block }
    end
  end
end
