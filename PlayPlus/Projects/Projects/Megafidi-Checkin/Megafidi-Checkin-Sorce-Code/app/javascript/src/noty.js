import Noty from 'noty';
// import "noty/src/noty.scss";
// import "noty/src/themes/mint.scss";
// import "noty/src/themes/bootstrap-v4.scss";

window.Noty = Noty;

// type => alert, success, warning, error, info/information

document.addEventListener("DOMContentLoaded", function() {
  Noty.overrideDefaults({
    theme: "mint",
    timeout: 3000,
    visibilityControl: true
  });

  if (gon.noty_message){
    gon.noty_message.forEach((noty) => {
      new Noty({
        type: noty.type,
        text: noty.text
      }).show();

    })
  }

});

// doc https://ned.im/noty