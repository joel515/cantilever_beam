module BeamsHelper
  def pluralize_without_count(count, noun, text = nil)
    count == 1 ? "#{noun}#{text}" : "#{noun.pluralize}#{text}"
  end

  def unpluralize_without_count(count, noun, text = nil)
    count == 1 ? "#{noun.pluralize}#{text}" : "#{noun}#{text}"
  end

  def status_label(beam, **opts)
    label_class = "label-default"

    if beam
      status = beam.check_status

      if beam.completed?
        label_class = "label-success"
      elsif beam.failed?
        label_class = "label-danger"
      elsif beam.running?
        label_class = "label-primary"
      elsif beam.active?
        label_class = "label-info"
      end
    end

    text = opts[:text].nil? ? status : "#{opts[:text]} - #{status}"

    "<span class=\"label #{label_class}\">#{text}</span>".html_safe
  end

  def number_with_units(beam, param, **opts)
    precision = opts[:precision].nil? ? 4 : opts[:precision]
    is_result = opts[:is_result].nil? ? false : true
    if is_result
      number = beam.unconvert(param)
      significant = true
    else
      number = beam.send(param.to_s)
      significant = false
    end

    value = number_with_precision(number,
                                  precision: precision,
                                  significant: significant,
                                  strip_insignificant_zeros: true)
    unit = beam.unit_text(param, is_result)

    "#{value} #{unit}".html_safe
  end

  def button(beam, type, opts = { text: true, size: 'btn-md' })
    if type == :submit
      link_to "<span class='glyphicon glyphicon-play'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        submit_beam_path(beam),
        method: :put,
        class: "btn btn-success #{opts[:size]}",
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'Submit job to cluster'
    elsif type == :edit
      link_to "<span class='glyphicon glyphicon-pencil'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        edit_beam_path(beam),
        class: "btn btn-info #{opts[:size]}",
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'Edit beam'
    elsif type == :delete
      link_to "<span class='glyphicon glyphicon-trash'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        beam,
        method: :delete,
        class: "btn btn-danger #{opts[:size]}",
        data: { confirm: 'Are you sure?', toggle: 'tooltip',
          placement: 'top' },
        title: 'Delete beam'
    elsif type == :copy
      link_to "<span class='glyphicon glyphicon-copy'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        copy_beam_path(beam),
        method: :put,
        class: "btn btn-default #{opts[:size]}",
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'Copy beam'
    elsif type == :clean
      link_to "<span class='glyphicon glyphicon-remove'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        clean_beam_path(beam),
        method: :put,
        class: "btn btn-warning #{opts[:size]}",
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'Clean job directory'
    elsif type == :results
      link_to "<span class='glyphicon glyphicon-eye-open'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        results_beam_path(beam),
        class: "btn btn-primary #{opts[:size]}",
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'View results'
    end
  end
end
