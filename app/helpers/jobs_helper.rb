module JobsHelper
  def status_label(job, **opts)
    label_class = "label-default"

    if job
      status = job.check_status
      job.set_status! status if status != job.status

      if job.completed?
        label_class = "label-success"
      elsif job.failed?
        label_class = "label-danger"
      elsif job.running?
        label_class = "label-primary"
      elsif job.active?
        label_class = "label-info"
      end
    end

    text = opts[:text].nil? ? status : "#{opts[:text]} - #{status}"

    "<span class=\"label #{label_class}\">#{text}</span>".html_safe
  end
end
