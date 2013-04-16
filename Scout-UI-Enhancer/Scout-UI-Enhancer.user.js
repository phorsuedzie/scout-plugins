// ==UserScript==
// @name        Scout-UI-Enhancer
// @namespace   http://www.infopark.de
// @description Enhances the Scout plugin edit page to ease the editing of the ignore patterns of the Infopark-Scout-Logcheck plugin.
// @include     https://scoutapp.com/infopark/clients/*/plugins/*/edit
// @include     https://scoutapp.com/infopark/roles/*/plugin_templates/*/edit
// @version     1
// ==/UserScript==

var original_id = "plugin_option_attributes_ignore";
var original_name = 'plugin[option_attributes][ignore]';
var original_input = document.getElementById(original_id);
if (!original_input) {
  original_name = "plugin_template[option_attributes][ignore]"
  original_id = "plugin_template_option_attributes_ignore";
  original_input = document.getElementById(original_id);
}
var lines = original_input.value.split('↓').join("\n");
var td = original_input.parentElement;
td.removeChild(original_input);
var textarea = document.createElement('textarea');
textarea.setAttribute('id', original_id);
textarea.setAttribute('name', original_name);
textarea.appendChild(document.createTextNode(lines));
td.appendChild(textarea);
var p = td;
while (p != undefined && p.nodeName != 'FORM') {
  p = p.parentElement;
}
var form = p;
form.onsubmit = function() {
  var ignore_textarea = document.getElementById(original_id);
  ignore_textarea.value = ignore_textarea.value.split("\n").join("↓");
  return true;
};
