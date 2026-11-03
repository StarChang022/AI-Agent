module ApplicationHelper

  include Pagy::Frontend

  def link_to_build_object(name, f, association, **arg)
    id, form = build_form(f, association, **arg)
    link_to(name, "#!", class: "build-object-btn " + arg[:class], data: {id: id, target: "##{association}", form: form})
  end

  def link_to_uppy_trigger(name, f, association, **arg)
    id, form = build_form(f, association, **arg)
    link_to(name, "#!", class: " " + arg[:class], data: {behavior: "uppy-trigger", id: id, target: "##{association}", form: form})
  end

  def build_form(f, association, **arg)
    new_object = f.object.send(association).klass.new
    id = new_object.object_id
    partial = arg[:partial] || association.singularize
    form = f.fields_for association, new_object, child_index: id do |builder|
      render(partial: partial, locals: {f: builder})
    end
    [id, form.gsub("\n", "")]
  end

  def bootstrap_devise_error_messages!
    return '' if resource.errors.empty?

    messages = resource.errors.full_messages.map { |message| content_tag(:li, message) }.join
    sentence = I18n.t(
      'errors.messages.not_saved',
      count: resource.errors.count,
      resource: resource.class.model_name.human.downcase
    )

    html = <<-HTML
    <div class="alert alert-danger">
      <button type="button" class="close" data-dismiss="alert" aria-label="Close">
        <span aria-hidden="true">&times;</span>
      </button>
      <h4 class="alert-heading">#{sentence}</h4>
      <ul class="mb-0">#{messages}</ul>
    </div>
    HTML

    html.html_safe
  end

  def model_icon(i)
    current_class = i.to_s.underscore.singularize
    case current_class
    when ""
    else
      icon = "info"
    end
    return "<i class='fa fa-#{icon}'></i>"
  end

  def parent_layout(layout)
    @view_flow.set(:layout, output_buffer)
    output = render(:file => "layouts/#{layout}")
    self.output_buffer = ActionView::OutputBuffer.new(output)
  end

  def content_without_attachment content
    content = Nokogiri::HTML(content)
    content.search('.//action-text-attachment').remove
    return content.search('.//body').inner_html
  end

  def content_without_attachment_data content
    _content = content.body

    _content = _content.to_html
    ["left", "center", "right"].each do |i|
      _content = _content.gsub("<div-text-#{i}>", "<div class='text-#{i}'>").gsub("</div-text-#{i}>", "</div>")
    end

    content.body = _content

    content = content.to_s

    content = Nokogiri::HTML(content)
    content.css('.attachment__name').remove
    content.css('.attachment__size').remove
    return content.search('.//body').inner_html
  end

  def truncate_with_nokogiri content, length = 200
    truncate(content, :length => 10000, escape: false)
  end

  def date_format date
    date&.strftime("%F")
  end

  def datetime_format datetime
    datetime&.strftime("%F %R")
  end

  def price_format price
    "$ #{number_with_delimiter(price, :delimiter => ',')}"
  end

  def active(i, j)
    if i.to_s == j.to_s
      return "active"
    end
  end

  def anonymize_phone(phone)
    phone&.sub(/(\d{2})\d{3}(\d{4})/, '\1***\2') || ''
  end

end
