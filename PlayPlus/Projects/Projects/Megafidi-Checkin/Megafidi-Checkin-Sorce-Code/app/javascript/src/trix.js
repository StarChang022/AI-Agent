import Trix from "trix"

addHeadingAttributes()
addAlignAttributes()
addForegroundColorAttributes()
addBackgroundColorAttributes()

addEventListener("trix-initialize", function (event) {
  new RichText(event.target)
})

addEventListener("trix-action-invoke", function (event) {

  if (event.actionName == "x-horizontal-rule") {
    insertHorizontalRule()
  };

  function insertHorizontalRule() {
    event.target.editor.insertAttachment(buildHorizontalRule())
  }

  function buildHorizontalRule() {
    return new Trix.Attachment({ content: "<hr>", contentType: "vnd.rubyonrails.horizontal-rule.html" })
  }
})

Trix.HTMLParser.allowedAttributes = "style href src width height class alt".split(" ")

class RichText {
  constructor(element) {
    let _element = element
    this.element = element

    this.insertHeadingElements()
    this.insertDividerElements()
    this.insertColorElements()
    this.insertYt()
    this.insertAlign()

    let embedYt = this.dialogsElement.querySelector(".embedYt")
    embedYt.addEventListener("click", function(event){
      let dialog = this.closest(".trix-dialog__link-fields")
      let input = dialog.querySelector("input[name='src']")
      let src = input.value

      if(src.indexOf('youtube.com/watch') >= 0){
        let params = new URL(src).searchParams;
        if(params.has('v')){
          let youtube_id = params.get('v')
          insertPreviewImage(youtube_id)
        }
      }else if(src.indexOf('youtu.be/') >= 0){
        let youtube_id = new URL(src).pathname.split("/")[1]
        insertPreviewImage(youtube_id)
      }else{
        new Noty({text: "Youtube影片網址錯誤", type: 'error'}).show();
      }
    })

    function insertPreviewImage(youtube_id){
      // let attachment = new Trix.Attachment({content: `<iframe width="560" height="315" src="https://www.youtube.com/embed/${youtube_id}" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>`})
      // element.editor.insertAttachment(attachment)
      _element.editor.insertHTML(`<img src="https://img.youtube.com/vi/${youtube_id}/0.jpg" data-youtube_id="${youtube_id}" youtube_id="${youtube_id}">`);
    }

  }

  insertAlign(){
    this.insertAlignButton()
    this.insertDialogAlign()
  }

  insertAlignButton(){
    this.buttonGroupBlockTools.insertAdjacentHTML("afterbegin", this.alignButtonTemplate)
  }

  insertDialogAlign(){
    this.dialogsElement.insertAdjacentHTML("beforeend", this.dialogAlignTemplate)
  }

  insertYt(){
    this.insertYtButton()
    this.insertDialogYt()
  }

  insertYtButton(){
    this.buttonGroupBlockTools.insertAdjacentHTML("beforeend", this.ytButtonTemplate)
  }

  insertDialogYt(){
    this.dialogsElement.insertAdjacentHTML("beforeend", this.dialogYtTemplate)
  }

  insertHeadingElements() {
    this.removeOriginalHeadingButton()
    this.insertNewHeadingButton()
    this.insertHeadingDialog()
  }

  removeOriginalHeadingButton() {
    this.buttonGroupBlockTools.removeChild(this.originalHeadingButton)
  }

  insertNewHeadingButton() {
    this.buttonGroupBlockTools.insertAdjacentHTML("afterbegin", this.headingButtonTemplate)
  }

  insertHeadingDialog() {
    this.dialogsElement.insertAdjacentHTML("beforeend", this.dialogHeadingTemplate)
  }

  insertDividerElements() {
    this.quoteButton.insertAdjacentHTML("afterend", this.horizontalButtonTemplate)
  }

  insertColorElements() {
    this.insertColorButton()
    this.insertDialogColor()
  }

  insertColorButton() {
    this.buttonGroupTextTools.insertAdjacentHTML("beforeend", this.colorButtonTemplate)
  }

  insertDialogColor() {
    this.dialogsElement.insertAdjacentHTML("beforeend", this.dialogColorTemplate)
  }

  get buttonGroupBlockTools() {
    return this.toolbarElement.querySelector("[data-trix-button-group=block-tools]")
  }

  get buttonGroupTextTools() {
    return this.toolbarElement.querySelector("[data-trix-button-group=text-tools]")
  }

  get dialogsElement() {
    return this.toolbarElement.querySelector("[data-trix-dialogs]")
  }

  get originalHeadingButton() {
    return this.toolbarElement.querySelector("[data-trix-attribute=heading1]")
  }

  get quoteButton() {
    return this.toolbarElement.querySelector("[data-trix-attribute=quote]")
  }

  get toolbarElement() {
    return this.element.toolbarElement
  }

  get horizontalButtonTemplate() {
    return '<button type="button" class="trix-button trix-button--icon trix-button--icon-horizontal-rule" data-trix-action="x-horizontal-rule" tabindex="-1" title="Divider">Divider</button>'
  }

  get ytButtonTemplate() {
    return '<button type="button" class="trix-button trix-button--icon trix-button--icon-yt" data-trix-action="x-yt" tabindex="-1" title="Youtube">Youtube</button>'
  }

  get dialogYtTemplate() {
    return `
    <div class="trix-dialog trix-dialog--yt" data-trix-dialog="x-yt" data-trix-dialog-attribute="x-yt">
    <div class="trix-dialog__link-fields">
    <input type="url" name="src" class="trix-input trix-input--dialog" placeholder="Enter a URL…" aria-label="URL" data-trix-input="">
    <div class="trix-button-group">
    <input type="button" class="trix-button trix-button--dialog embedYt" value="Embed">
    </div>
    </div>
    </div>
    `
  }

  get headingButtonTemplate() {
    return '<button type="button" class="trix-button trix-button--icon trix-button--icon-heading-1" data-trix-action="x-heading" title="Heading" tabindex="-1">Heading</button>'
  }

  get colorButtonTemplate() {
    return '<button type="button" class="trix-button trix-button--icon trix-button--icon-color" data-trix-action="x-color" title="Color" tabindex="-1">Color</button>'
  }

  get alignButtonTemplate(){
    return '<button type="button" class="trix-button trix-button--icon trix-button--icon-align" data-trix-action="x-align" title="Align" tabindex="-1">Align</button>'
  }

  get dialogHeadingTemplate() {
    return `
    <div class="trix-dialog trix-dialog--heading" data-trix-dialog="x-heading" data-trix-dialog-attribute="x-heading">
    <div class="trix-dialog__link-fields">
    <input type="text" name="x-heading" class="trix-dialog-hidden__input" data-trix-input>
    <div class="trix-button-group">
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="heading1">H1</button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="heading2">H2</button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="heading3">H3</button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="heading4">H4</button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="heading5">H5</button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="heading6">H6</button>
    </div>
    </div>
    </div>
    `
  }

  get dialogColorTemplate() {
    return `
    <div class="trix-dialog trix-dialog--color" data-trix-dialog="x-color" data-trix-dialog-attribute="x-color">
    <div class="trix-dialog__link-fields">
    <input type="text" name="x-color" class="trix-dialog-hidden__input" data-trix-input>
    <div class="trix-button-group">
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor1" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor2" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor3" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor4" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor5" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor6" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor7" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor8" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="fgColor9" data-trix-method="hideDialog"></button>
    </div>
    <div class="trix-button-group">
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="bgColor1" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="bgColor2" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="bgColor3" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="bgColor4" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="bgColor5" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="bgColor6" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="bgColor7" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="bgColor8" data-trix-method="hideDialog"></button>
    <button type="button" class="trix-button trix-button--dialog" data-trix-attribute="bgColor9" data-trix-method="hideDialog"></button>
    </div>
    </div>
    </div>
    `
  }

  get dialogAlignTemplate() {
    return `
    <div class="trix-dialog trix-dialog--align" data-trix-dialog="x-align" data-trix-dialog-attribute="x-align">
    <div class="trix-dialog__link-fields">
    <input type="text" name="x-align" class="trix-dialog-hidden__input" data-trix-input>
    <div class="trix-button-group">
    <button type="button" class="trix-button trix-button--icon trix-button--align-left" data-trix-attribute="align-left" data-trix-method="hideDialog">Left</button>
    <button type="button" class="trix-button trix-button--icon trix-button--align-center" data-trix-attribute="align-center" data-trix-method="hideDialog">Center</button>
    <button type="button" class="trix-button trix-button--icon trix-button--align-right" data-trix-attribute="align-right" data-trix-method="hideDialog">Right</button>
    </div>
    </div>
    </div>
    `
  }


}

function addHeadingAttributes() {
  Array.from(["h1", "h2", "h3", "h4", "h5", "h6"]).forEach((tagName, i) => {
    //Trix.config.blockAttributes[`heading${(i + 1)}`] = { tagName: tagName, terminal: true, breakOnReturn: true, group: false }
    Trix.config.blockAttributes[`heading${(i + 1)}`] = { tagName: tagName}
  })
}

function addAlignAttributes() {
  Array.from(["left", "center", "right"]).forEach((align, i) => {
    //Trix.config.blockAttributes[`align-${align}`] = {tagName: `div-text-${align}`, terminal: true, breakOnReturn: true, group: false }
    Trix.config.blockAttributes[`align-${align}`] = {tagName: `div-text-${align}`}
  })
}

function addForegroundColorAttributes() {
  Array.from(["rgb(136, 118, 38)", "rgb(185, 94, 6)", "rgb(207, 0, 0)", "rgb(216, 28, 170)", "rgb(144, 19, 254)", "rgb(5, 98, 185)", "rgb(17, 138, 15)", "rgb(148, 82, 22)", "rgb(102, 102, 102)"]).forEach((color, i) => {
    Trix.config.textAttributes[`fgColor${(i + 1)}`] = { style: { color: color }, inheritable: true, parser: e => e.style.color == color }
  })
}

function addBackgroundColorAttributes() {
  Array.from(["rgb(250, 247, 133)", "rgb(255, 240, 219)", "rgb(255, 229, 229)", "rgb(255, 228, 247)", "rgb(242, 237, 255)", "rgb(225, 239, 252)", "rgb(228, 248, 226)", "rgb(238, 226, 215)", "rgb(242, 242, 242)"]).forEach((color, i) => {
    Trix.config.textAttributes[`bgColor${(i + 1)}`] = { style: { backgroundColor: color }, inheritable: true, parser: e => e.style.backgroundColor == color }
  })
}