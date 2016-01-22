module UnitsHelper
  def unit_text(object, param, result_units = false)
    if result_units == false
      UNIT_DESIGNATION[param][object.send(param.to_s<<"_unit").to_sym][:text] unless
        UNIT_DESIGNATION[param].nil?
    else
      RESULT_UNITS[object.result_unit_system.to_sym][param][:text]
    end
  end

  def convert(object, param)
    object.send(param.to_s) * \
      UNIT_DESIGNATION[param][object.send(param.to_s<<"_unit").to_sym][:convert] \
      unless UNIT_DESIGNATION[param].nil?
  end

  def unconvert(object, param)
    object.send(param.to_s) / \
      RESULT_UNITS[object.result_unit_system.to_sym][param][:convert]
  end
end
