module BeamsHelper

  def status_label(beam, **opts)
    label_class = "label-default"

    if beam
      status = beam.status

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

  def button(beam, type, opts = { text: true, size: 'btn-md' })
    if type == :submit
      link_to "<span class='glyphicon glyphicon-play-circle'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        submit_beam_path(beam),
        method: :put,
        class: "btn btn-success #{opts[:size]}",
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'Submit job to cluster'
    elsif type == :edit
      link_to "<span class='glyphicon glyphicon-edit'></span> "\
          "#{type.capitalize if opts[:text]}".html_safe,
        edit_beam_path(beam),
        class: "btn btn-primary #{opts[:size]}",
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
        beam,
        class: "btn btn-info #{opts[:size]}",
        data: { toggle: 'tooltip', placement: 'top' },
        title: 'Copy beam'
    end
  end
end
