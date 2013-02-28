module Identity
  class ExconInstrumentor
    attr_accessor :events

    def initialize(extra_data={})
      @extra_data = extra_data
    end

    def instrument(name, params={}, &block)
      data = [
        [:app,     "identity"],
        [:host,    params[:host]],
        [:path,    params[:path]],
        [:method,  params[:method]],
        [:expects, params[:expects]],
        [:status,  params[:status]],
      ]
      # dump everything on an error
      data += params.map { |k, v| [k, v] } if name == "excon.error"
      data += @extra_data
      Slides.log_array(name, data) { block.call if block }
    end
  end
end
