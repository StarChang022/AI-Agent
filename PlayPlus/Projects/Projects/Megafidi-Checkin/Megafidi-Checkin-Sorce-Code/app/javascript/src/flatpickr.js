import flatpickr from 'flatpickr'
import "flatpickr/dist/l10n/zh-tw"

document.addEventListener('DOMContentLoaded', function(){
  flatpickr.localize(flatpickr.l10ns.zh_tw);

  flatpickr(".datepicker", {
		dateFormat: "Y/m/d",
	});

  flatpickr(".datetimepicker", {
    enableTime: true,
    time_24hr: true
  })

  flatpickr(".daterange", {
    mode: "range",
    maxDate: "today",
    dateFormat: "Y/m/d",
    locale: {
      rangeSeparator: '-'
    }
  });


  flatpickr(".daterangepicker", {
    mode: "range",
    maxDate: "today",
    dateFormat: "Y/m/d",
    locale: {
      rangeSeparator: '-'
    }
  });


})
