class BootstrapVerticalFormBuilder < ActionView::Helpers::FormBuilder

  def self.bootstrap_alias(method_name)
    alias_method :"#{method_name}_without_bootstrap", method_name
    alias_method method_name, :"bootstrap_#{method_name}"
  end

  def container_tag(base_dom_class, content_or_options = nil, options = {}, &block)
    options = content_or_options if content_or_options.is_a?(Hash)
    content_or_options = @template.capture(&block) if block_given?
    options[:class] = [options.dig(:class), base_dom_class].compact.join(" ")
    @template.content_tag(:div, content_or_options, options)
  end

  def field_container(content_or_options = nil, options = {}, &block)
    container_tag "mb-3", content_or_options, options, &block
  end

  def around_input(method, options = {}, &block)
    options[:class] = [options.delete(:class), "form-control form-control-sm"].compact.join(" ")
    help_text = options.delete(:help) || fetch_i18n_help_text(method)
    help_tag = help_text ? @template.content_tag(:p, help_text, class: "form-text text-muted") : ""
    input_html = @template.capture(&block)

    label_tag(method, options) + container_tag("", input_html + help_tag + error_message(method, tag: "p", class: "text-danger"))
  end

  def label_tag(method, options = {})
    options[:hide_label] ? @template.raw("") : @template.content_tag(:div, label(method, options.delete(:label), class: "form-label"), class: "")
  end

  def self.bootstrap_field(field_method_name)
    define_method "bootstrap_#{field_method_name}" do |method, options = {}|
      field_container do
        around_input(method, options) do
          send("#{field_method_name}_without_bootstrap", method, options)
        end
      end
    end
    bootstrap_alias field_method_name
  end

  %i[url_field color_field file_field date_field email_field password_field text_field datetime_field datetime_local_field number_field phone_field range_field].each do |field_name|
    bootstrap_field field_name
  end

  def bootstrap_select(method, choices = nil, options = {}, html_options = {}, &block)
    field_container do
      html_options[:class] = [html_options.delete(:class), "form-control form-control-sm"].compact.join(" ")
      around_input(method, options) do
        select_without_bootstrap(method, choices, options, html_options, &block)
      end
    end
  end

  def bootstrap_text_area(method, options = {})
    field_container do
      around_input(method, options) do
        text_area_without_bootstrap(method, options)
      end
    end
  end

  def bootstrap_collection_radio_buttons(method, collection, value_method, text_method, options = {}, html_options = {})
    field_container do
      around_input(method, options) do
        collection_radio_buttons_without_bootstrap(method, collection, value_method, text_method, options, html_options) do |b|
          @template.content_tag(:div, b.radio_button(class: "form-check-input") + b.label(class: "form-check-label"), class: "form-check form-check-inline")
        end
      end
    end
  end

  def bootstrap_collection_check_boxes(method, collection, value_method, text_method, options = {}, html_options = {})
    field_container do
      around_input(method, options) do
        collection_check_boxes_without_bootstrap(method, collection, value_method, text_method, options, html_options) do |b|
          @template.content_tag(:div, b.check_box(class: "form-check-input") + b.label(class: "form-check-label"), class: "form-check form-check-inline")
        end
      end
    end
  end

  def bootstrap_submit (method, options = {})
    field_container do

      # submit 按鈕樣式
      base_dom_class = "btn btn-light"
      options[:class] = [options.dig(:class), base_dom_class].compact.join(" ")
      options[:data] ||= {}
      options[:data]["disable-with"] ||= I18n.t("backends.submiting")

      label_tag(" ", options) + container_tag("", submit_without_bootstrap(method, options) )
    end
  end

  %i[select submit text_area collection_radio_buttons collection_check_boxes].each{|fn| bootstrap_alias(fn)}

  private

  def fetch_i18n_help_text(method)
    t_scope = ["helpers", "help", @object_name, method].join(".")
    #t_scope = ["helpers", "help", object.class.model_name.param_key, method].join(".")

    I18n.t(t_scope, default: nil)
  end

end