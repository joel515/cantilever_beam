module BeamsHelper

  def number_with_units(object, param, **opts)
    precision = opts[:precision].nil? ? 4 : opts[:precision]
    is_result = opts[:is_result].nil? ? false : true
    if is_result
      number = unconvert(object, param)
      significant = true
    else
      number = object.send(param.to_s)
      significant = false
    end

    value = number_with_precision(number,
                                  precision: precision,
                                  significant: significant,
                                  strip_insignificant_zeros: true)
    unit = unit_text(object, param, is_result)

    "#{value} #{unit}".html_safe
  end

  def button(beam, type, opts = { text: false, size: 'btn-xs',
    disabled: false })

    if type == :submit
      link_to "<span class='glyphicon glyphicon-flash'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        submit_job_path(beam.job),
        method: :put,
        class: "btn btn-success #{opts[:size]} " \
          "#{'disabled' * opts[:disabled].to_i}".strip,
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'Submit job to cluster'
    elsif type == :edit
      link_to "<span class='glyphicon glyphicon-pencil'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        edit_beam_path(beam),
        class: "btn btn-fteblue #{opts[:size]} " \
          "#{'disabled' * opts[:disabled].to_i}".strip,
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'Edit beam'
    elsif type == :delete
      link_to "<span class='glyphicon glyphicon-trash'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        beam,
        method: :delete,
        class: "btn btn-ftered #{opts[:size]} " \
          "#{'disabled' * opts[:disabled].to_i}".strip,
        data: { confirm: 'Are you sure?', toggle: 'tooltip',
          placement: 'top' },
        title: 'Delete beam'
    elsif type == :copy
      link_to "<span class='glyphicon glyphicon-duplicate'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        copy_beam_path(beam),
        method: :put,
        class: "btn btn-ftegray #{opts[:size]} " \
          "#{'disabled' * opts[:disabled].to_i}".strip,
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'Copy beam'
    elsif type == :clean
      link_to "<span class='glyphicon glyphicon-erase'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        clean_beam_path(beam),
        method: :put,
        class: "btn btn-fteyellow #{opts[:size]} " \
          "#{'disabled' * opts[:disabled].to_i}".strip,
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'Clean job directory'
    elsif type == :results
      link_to "<span class='glyphicon glyphicon-stats'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        results_beam_path(beam),
        class: "btn btn-primary #{opts[:size]} " \
          "#{'disabled' * opts[:disabled].to_i}".strip,
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'View results'
    elsif type == :refresh
      link_to "<span class='glyphicon glyphicon-refresh'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        request.original_url,
        class: "btn btn-info #{opts[:size]} " \
          "#{'disabled' * opts[:disabled].to_i}".strip,
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'Refresh page'
    elsif type == :kill
      link_to "<span class='glyphicon glyphicon-remove'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        kill_job_path(beam.job),
        method: :put,
        class: "btn btn-danger #{opts[:size]} " \
          "#{'disabled' * opts[:disabled].to_i}".strip,
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'Kill job'
    elsif type == :stdout
      link_to "<span class='glyphicon glyphicon-open-file'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        stdout_job_path(beam.job),
        class: "btn btn-ftegreen #{opts[:size]} " \
          "#{'disabled' * opts[:disabled].to_i}".strip,
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'View standard output',
        target: '_blank'
    end
  end

  def button_group(beam, opts = { text: false, size: 'btn-xs'} )
    div = "<div class=\"btn-group\">"
    if beam.ready?
      div += button(beam, :submit, opts)
    else
      if beam.active? || beam.running?
        div += button(beam, :kill,  opts)
        opts[:disabled] = true
      else
        div += button(beam, :clean,  opts)
      end
    end

    div += button(beam, :edit,   opts)
    div += button(beam, :copy,   opts)
    div += button(beam, :delete, opts)
    div += "</div>"
    div.html_safe
  end

  def result_table(beam, result)
    analysis_result =
      !beam.send(result.to_s<<"_fem").nil? ? number_with_units(beam,
      (result.to_s<<"_fem").to_sym, is_result: true) : "N/A"
    theory_result = number_with_units(beam, result, is_result: true)

    error = beam.error(result)
    if !error.nil?
      if error.abs <= 5
        formatted_error = content_tag(:font, "%.2f%" % error, color: "green")
      elsif error.abs <= 10
        formatted_error = content_tag(:font, "%.2f%" % error, color: "orange")
      else
        formatted_error = content_tag(:font, "%.2f%" % error, color: "red")
      end
    else
      formatted_error = "N/A"
    end

    "<td>#{analysis_result}</td>" \
    "<td>#{theory_result}</td>" \
    "<td>#{formatted_error}</td>".html_safe
  end
end
