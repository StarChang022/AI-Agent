
RailsJSPrompt = {
  prompt: function(l){
    var link = $(l);

    var href = link.attr('href'),
    method = link.data('method'),
    target = link.attr('href'),
    remote = link.data('remote'),
    csrfToken = $('meta[name=csrf-token]').attr('content'),
    csrfParam = $('meta[name=csrf-param]').attr('content'),
    form = $('<form method="post" action="' + href + '" data-remote="true"></form>'),
    metadataInput = '<input name="_method" value="' + method + '" type="hidden" />',
    msg = link.data('prompt'),
    value = prompt(msg),
    paramName = link.data('param-name') || 'prompt-value',
    promptParamInput = '<input name="' + paramName + '" value="' + value + '" type="hidden" />';
    submitButton = "<button type='submit'>submit</button>"
    if (csrfParam !== undefined && csrfToken !== undefined) {
      metadataInput += '<input name="' + csrfParam + '" value="' + csrfToken + '" type="hidden" />';
    }

    form.hide().append(metadataInput).append(promptParamInput).append(submitButton).appendTo('body');
    form.find("button[type='submit']").click();
  }
}

$(document).on('click', 'a[data-prompt]', function(e) {
  e.preventDefault();
  e.stopImmediatePropagation();
  RailsJSPrompt.prompt(this);
});