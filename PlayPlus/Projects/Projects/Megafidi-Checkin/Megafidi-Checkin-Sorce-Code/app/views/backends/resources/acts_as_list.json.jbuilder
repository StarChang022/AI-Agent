json.collection do
  json.array! current_collection, partial: 'show', as: :current_object
end