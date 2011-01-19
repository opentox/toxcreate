$(function() {

  jQuery.fn.toggleWarnings = function(id) {
    var id = id;
    this.bind("click", function() {
      if($("a#show_model_" + id + "_warnings").html()=="show") {
        $("dd#model_" + id + "_warnings").slideDown("slow");
        $("a#show_model_" + id + "_warnings").html("hide");
      }else{
        $("dd#model_" + id + "_warnings").slideUp("slow");
        $("a#show_model_" + id + "_warnings").html("show");
      }
      return false;
    });
  };

  trim = function() {
    return this.replace(/^\s+|\s+$/g, '');
  }

  checkStati = function(stati, subjectstr) {
    stati = stati.split(", ");
    $("body")
    var newstati = new Array;
    $.each(stati, function(){
      if(checkStatus(this, subjectstr) > 0) newstati.push(this);
    });  
    if (newstati.length > 0) var statusCheck = setTimeout('checkStati("' + newstati.join(", ") + '", "' + subjectstr + '")',10000);
  };
  
  checkStatus = function(id, subjectstr) {
    if(id == "") return -1; 
    var opts = {method: 'get', action: 'model/' + id + '/status' + subjectstr, id: id};
    var status_changed = $.ajax({
      type: opts.method,
      url: opts.action,
      async: false,
      dataType: 'html',
      data: {
        '_method': 'get'
      },
      success: function(data) {
        var status_before = "";
        if ($("span#model_" + id + "_status") !== null) status_before = $("span#model_" + id + "_status").html().trim();
        var status_after  = data.trim();
        $("span#model_" + id + "_status").animate({"opacity": "0.2"},1000);
        $("span#model_" + id + "_status").animate({"opacity": "1"},1000);
        if( status_before != status_after) {
          $("span#model_" + id + "_status").html(data);        
          loadModel(id, 'model');
          if (status_after == "Completed") id = -1;
        }        
      },
      error: function(data) {
        //alert("status check error");
        id = -1;
      }
    });
    return id;
  };

  loadModel = function(id, view) {
    if(id == "") return -1; 
    var opts = {method: 'get', action: 'model/' + id + '/' + view, view: view };
    var out = id;
    $.ajax({
      type: opts.method,
      url: opts.action,
      dataType: 'html',
      data: {
        '_method': 'get'
      },
      success: function(data) {
        if (view == "model") $("div#model_" + id).html(data);
        if (view.match(/validation/)) $("dl#model_validation_" + id).html(data);
      },
      error: function(data) {
        //alert("loadModel error");
      }
    });
    return false;
  };

  checkValidation = function() {
    var reload_id = "";
    $("input.model_validation_report").each(function(){
        if(!$(this).val().match(/Completed|Error/)) {
          reload_id = this.id.replace("model_validation_report_","");
          if(/^\d+$/.test(reload_id)) loadModel(reload_id, 'validation');
        };
    });
    //var validationCheck = setTimeout('checkValidation()',15000);
    var validationCheck = setTimeout('checkValidation()',5000);
  }
});

jQuery.fn.deleteModel = function(type, options) {
  var defaults = {
    method: 'post',
    action: this.attr('href'),
    confirm_message: 'Are you sure?',
    trigger_on: 'click'
  };
  var opts = $.extend(defaults, options);
  this.bind(opts.trigger_on, function() {
    if(confirm(opts.confirm_message)) {
      $("div#model_" + opts.id).fadeTo("slow",0.5);
      $("span#model_" + opts.id + "_status").html("Deleting");
      $.ajax({
         type: opts.method,
         url:  opts.action,
         dataType: 'html',
         data: {
           '_method': 'delete'
         },
         success: function(data) {         
           $("div#model_" + opts.id).fadeTo("slow",0).slideUp("slow").remove();
         },
         error: function(data) {
           $("span#model_" + opts.id + "_status").html("Delete Error");
           //alert("model delete error!");
         }
       });
     }
     return false;
   });
};
