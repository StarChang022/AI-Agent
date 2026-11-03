json.extract! current_object, *current_object.class.column_names.map(&:to_sym)
