/*
 * Copyright (c) 2006 Byrne Reese. All rights reserved.
 * version 0.1
 * http://www.majordojo.com/projects/javascript/tags-widget
 * 
 * This library is free software; you can redistribute it and/or modify it 
 * under the terms of the BSD License.
 *
 * This library is distributed in the hope that it will be useful, but 
 * WITHOUT ANY WARRANTY; without even the implied warranty of 
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
 *
 * @author Byrne Reese <byrne@majordojo.com>
 * @version 1.0
 */

/**
 * @class 
 * @constructor
 * @private
 */
RegExp.escape = (function() {
  var specials = [
    '/', '.', '*', '+', '?', '|',
    '(', ')', '[', ']', '{', '}', '\\'
  ];

  sRE = new RegExp(
    '(\\' + specials.join('|\\') + ')', 'g'
  );
  
  return function(text) {
    return text.replace(sRE, '\\$1');
  }
})();

/**
 * @class The TagList class is a helper class of sorts that represents the
 * current list of tags associated with the containing TagWidget. It exposes
 * events that can be subscribed to when tags are added and removed from the
 * list
 * @param {String} baseId The base ID for the widget. The baseId is appended
 * to all dynamically constructed DOM elements so that multiple tag widgets
 * can co-exist on the same page without conflicting or confusing one another.
 * @constructor
 * @requires YAHOO.util.CustomEvent As provided by the Yahoo User Interface Library
 * @requires YAHOO.util.Event As provided by the Yahoo User Interface Library
 */
function TagList( baseId ) {
  this.baseId = baseId;

  /**
   * This defines the base URL for all tag links. The text of the tag 
   * the user clicked on will be appended to this string.
   * @type string
   */
  this.TAG_LINK_FORMAT = 'http://www.somedomain.com/foo?tag=';

  /**
   * @type Array
   * @private
   */
  this.tags = new Array();

  /**
   * This is the event that gets fired off when the user deletes a
   * tag.
   * @type YAHOO.util.CustomEvent
   */
  this.deleteEvent = new YAHOO.util.CustomEvent("deleteEvent", this);

  /**
   * This is the event that gets fired off when the user deletes a
   * tag.
   * @return {Integer} representing the current number of tags
   */
  this.length = function ( ) {
    return this.tags.length;
  }

  /**
   * @private
   */
  this.deleteTag = function ( tag ) {
  	var s = tag.textContent;
    var node = YAHOO.util.Dom.get(this.baseId + '-tags');
    node.removeChild(tag);
		if(node.childNodes.length == 0)
			node.parentNode.removeChild(node.parentNode.lastChild);
		for(var i=0;i<this.tags.length;i++) {
			if(this.tags[i] == s)
				this.tags.splice(i, 1);
		}
    return true;
  }

  /**
   * @private
   */
  this.onDeleteClick = function ( e ) {
    YAHOO.util.Event.stopEvent(e);
    var target = YAHOO.util.Event.getTarget(e);
    //var id = target.parentNode.id;
    var id = target.parentNode.parentNode.parentNode.id;
    var x = id.substring(id.lastIndexOf('-') + 1, id.length);
    //this.deleteTag(target.parentNode.parentNode);
    this.deleteTag(target.parentNode.parentNode.parentNode);
    var idx = -1;
    for (var i = 0; i < this.tags.length; i++) {
      if (x == this.tags[i]) { idx = i; break; }
    }
    this.tags.splice(idx,1);
    this.deleteEvent.fire( x );
  }

  /**
   * @private
   */
  this.addTag = function ( str ) {
	if(!this.find(str)) {
   		this.tags[this.tags.length] = str;
    	this.renderTag(str);
	}
  }

  /**
   * @private
   */
  this.find = function (s) {
	for(var i=0;i<this.tags.length;i++)
		if(this.tags[i] == s) return true;
	return false;
  }
  
  /**
   * @private
   */
  this.getTagByStr = function (s) {
	for(var i=0;i<this.tags.length;i++)
		if(this.tags[i] == s) 
			return this.tags[i];
	return false;
  }

  /**
   * @private
   */
  this.renderTag = function ( str ) {
    var node = YAHOO.util.Dom.get(this.baseId + '-tags');
    if (!node) return;
    var li = document.createElement('li');
    li.id = this.baseId + '-tag-' + str;
    li.className = 'tag';
    var div = document.createElement('div');
    div.className = 'tag-wrapper';
    li.appendChild(div);
    var a1 = document.createElement('a');
    a1.innerHTML = str;
    a1.href = this.TAG_LINK_FORMAT + str;
    a1.id = this.baseId + '-lnk-tag-'+str;
    a1.className = 'lnk-tag';
    //var dellnk = document.createElement('a');
    var dellnk = document.createElement('span');
    dellnk.id = this.baseId + '-del-tag-' + str;
    dellnk.className = 'del-tag';
    //dellnk.href = '#';
    //dellnk.innerHTML = this.DELETE_HTML;

    var br = document.createElement('br');
    br.setAttribute('clear', 'all');
    br.id = this.baseId + '-br';
    a1.appendChild(dellnk);

    div.appendChild(a1);
    //div.appendChild(document.createTextNode(' '));
    //div.appendChild(dellnk);

    if (!document.getElementById(this.baseId + '-br')) {
      node.parentNode.appendChild(br);
    }

    node.appendChild(li);
    YAHOO.util.Event.addListener(dellnk, "click", this.onDeleteClick, this, true);
  }
}

/////////////////////////////////////////////////////////////////////

/**
 * @class The TagWidget class is the primary class that should be instantiated
 * directly by the user. 
 * @param {String} baseId The base ID for the widget. The baseId is appended
 *    to all dynamically constructed DOM elements so that multiple tag widgets
 *    can co-exist on the same page without conflicting or confusing one another.
 * @constructor
 * @requires YAHOO.util.CustomEvent As provided by the Yahoo User Interface Library
 * @requires YAHOO.util.Event As provided by the Yahoo User Interface Library
 */
function TagWidget( baseId ) {
  /**
   * Every widget needs a base id that is unique that will allow multiple
   * instances of this widget to co-exist on the same rendered page.
   * @type string
   */
  this.baseId = baseId;

  /**
   * Constant field indicating whether the add form should always be visible
   * @type boolean
   */
  this.ALWAYS_SHOW_FORM = 0;

  /**
   * Constant field representing the text to appear before the input text box
   * @type String
   */
  this.FORM_LABEL = 'Add tag(s):';

  /**
   * Constant field representing the text to appear before the list of tags
   * @type String
   */
  this.LIST_LABEL = 'Tags:';

  /**
   * Constant field representing the link text to appear for adding more tags
   * @type String
   */
  this.LINK_LABEL = 'Add Tags';

  /**
   * Constant field representing the label of the add button
   * @type String
   */
  this.ADD_LABEL = 'Add';

  /**
   * Constant field representing the label of the done button
   * @type String
   */
  this.DONE_LABEL = 'Done';

  /**
   * Constant field representing the delimiter you wish to use when a user\
   * enters more than one tag at a time.
   * @type String
   */
  this.TAG_DELIMITTER = ',';

  /**
   * The TagList object used to manage the set of tags associated with a TagWidget
   * @type TagList
   */
  this.taglist = new TagList(baseId);

  /**
   * Event hook for processing add tag events
   * @type YAHOO.util.CustomEvent
   */
  this.addEvent = new YAHOO.util.CustomEvent("addEvent", this);

  /**
   * Function that adds tags to the widget
   * @param {String} tag The tag you want to add to the widget
   */
  this.addTag = function ( tag ) {
    this.taglist.addTag(tag);
  }

  /**
   * Function that reveals the "Add tag(s):" form and brings focus to it
   * @private
   */
  this.showAddForm = function ( e ) {
    if ( e ) {
      YAHOO.util.Event.stopEvent(e);
    }
    YAHOO.util.Dom.get(this.baseId + '-add-tag').style.display = 'block';
    YAHOO.util.Dom.get(this.baseId + '-add-button').style.display = 'none';
    YAHOO.util.Dom.get(this.baseId + '-tag-str').focus();
    return false;
  }

  /**
   * @private
   */
  this.taglistplit = function ( str ) {
    var delim = RegExp.escape(this.TAG_DELIMITTER);
    var delim_scan = new RegExp('^((([\'"])(.*?)\\3|.*?)(' + delim + '\\s*|$))', '');
    str = str.replace(/(^\s+|\s+$)/g, '');
    var tags = [];
    while (str.length && str.match(delim_scan)) {
        str = str.substr(RegExp.$1.length);
        var tag = RegExp.$4 ? RegExp.$4 : RegExp.$2;
        tag = tag.replace(/(^\s+|\s+$)/g, '');
        tag = tag.replace(/\s+/g, ' ');
        if (tag != '') tags.push(tag);
    }
    return tags;
  }

  /**
   * Function that hides the "Add tag(s):" form
   * @private
   */
  this.hideAddForm = function ( e ) {
    YAHOO.util.Event.stopEvent(e);
    YAHOO.util.Dom.get(this.baseId + '-add-tag').style.display = 'none';
    YAHOO.util.Dom.get(this.baseId + '-add-button').style.display = 'block';
    return false;
  }

  /**
   * @private
   */
  this.onAddSubmit = function ( e ) {
    /* cancel submit event */
    YAHOO.util.Event.stopEvent(e);
    var node = YAHOO.util.Dom.get(this.baseId + '-tag-str');
    var str = node.value;
    if (str != "") { 
      this.addEvent.fire( str );
      //this.taglist.addTag(str); 
      var tags = this.taglistplit(str);
      for(i = 0; i < tags.length; i++) {
        this.taglist.addTag(tags[i]); 
      }
      node.value = '';
      return true;
    }
    return false;
  }

  /**
   * Function that renders the widget on the page. The function takes as an argument the 
   * DOM element id (in string form) on which to attach the widget
   * @param {String} id	The id of the element under which the widget should be drawn
   */
  this.render = function () {
    var node = YAHOO.util.Dom.get(this.baseId);
    if (!node) return;
    var e1 = document.createElement('div');
    e1.id = this.baseId + '-add-tag';
    e1.className = 'add-tag';
    var f1 = document.createElement('form');
    f1.id = this.baseId + '-add-tag-form';
    f1.className = 'add-tag-form';
    var i1 = document.createElement('input');
    i1.type = 'text';
    i1.id = this.baseId + '-tag-str';
    i1.className = 'tag-str';
    i1.name = 'tag';
    i1.size = '20';
    var i2 = document.createElement('input');
    i2.type = 'submit';
    i2.value = this.ADD_LABEL;
    i2.style.marginLeft = '5px';
    var i3 = document.createElement('input');
    i3.type = 'button';
    i3.value = this.DONE_LABEL;
    
    f1.appendChild(document.createTextNode(this.FORM_LABEL));
    f1.appendChild(i1);
    f1.appendChild(i2);
    if (!this.ALWAYS_SHOW_FORM) { f1.appendChild(i3); }
    e1.appendChild(f1);

    var e2 = document.createElement('div');
    e2.id = this.baseId + '-tag-label';
    e2.className = 'tag-label';
    e2.innerHTML = this.LIST_LABEL;

    var ul = document.createElement('ul');
    ul.id = this.baseId + '-tags';
    ul.className = 'tags';

    var a = document.createElement('a');
    a.id = this.baseId + '-add-button';
    a.className = 'add-button';
    a.href = '#';
    a.innerHTML = this.LINK_LABEL;

    node.appendChild(e1);
    node.appendChild(e2);
    node.appendChild(ul);
    node.appendChild(a);

    YAHOO.util.Event.addListener(a, "click", this.showAddForm, this, true);
    YAHOO.util.Event.addListener(i3, "click", this.hideAddForm, this, true);
    YAHOO.util.Event.addListener(f1, "submit", this.onAddSubmit, this, true); 

    for (var i = 0; i < this.taglist.tags.length; i++) {
      this.taglist.renderTag(this.taglist.tags[i]);
    }
    if (this.ALWAYS_SHOW_FORM) {
      this.showAddForm( null );
    }
  }
}