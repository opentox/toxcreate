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
      checkProgress(this, subjectstr);
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
        if ($("span#model_" + id + "_status") != null) status_before = $("span#model_" + id + "_status").html().trim();
        if (status_before == "Deleting") return -1;         
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
  
  
  checkProgress = function(id, subjectstr) {
    var task = $("input#model_" + id + "_task").attr('value');
    var opts = {action: task + "/percentageCompleted" , id: id};
    var progress_changed = $.ajax({
      url: opts.action,
      async: false,
      dataType: 'html',
      data: {
        '_method': 'get'
      },
      success: function(data) {
        var progress = data.trim();
        if (progress == "100") return -1;         
        
        $("div#model_" + id + "_progress").progressbar("value", parseInt(progress)); 
        $("div#model_" + id + "_progress").attr({title: parseInt(progress) + "%", alt: parseInt(progress) + "%"});
        //$("div#model_" + id + "_progress").attr("alt", parseInt(progress) + "%");
      },
      error: function(data) {
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

});

jQuery.fn.editModel = function(options) {
  var defaults = {
    method: 'get',
    action: this.attr('href'),
    trigger_on: 'click'
  };
  var opts = $.extend(defaults, options);
  this.bind(opts.trigger_on, function() {  
    $.ajax({
         type: opts.method,
         url:  opts.action,
         dataType: 'html',
         data: {
           '_method': 'get'
         },
         success: function(data) {         
           $("div#model_" + opts.id + "_name").html(data);
           $("input#model_" + opts.id + "_name").focus();
         },
         error: function(data) {
           alert("model edit error!");
         }
       });
    return false;
  });
};

jQuery.fn.editPolicy = function(options) {
  var defaults = {
    method: 'get',
    action: this.attr('href'),
    trigger_on: 'click'
  };
  var opts = $.extend(defaults, options);
  this.bind(opts.trigger_on, function() {  
    $.ajax({
         type: opts.method,
         url:  opts.action,
         dataType: 'html',
         data: {
           '_method': 'get'
         },
         success: function(data) {         
           $("div#model_" + opts.id + "_policy_edit").html(data);
           $("input#model_" + opts.id + "_name").focus();
         },
         error: function(data) {
           alert("model edit error!");
         }
       });
    return false;
  });
};

jQuery.fn.updatePolicy = function(options) {
  var defaults = {
    method: 'post',
    action: 'policy/' + options.policyname,
    trigger_on: 'click'
  };
  var opts = $.extend(defaults, options);
  this.bind(opts.trigger_on, function() {
    var groupname =  opts.groupname;
    var select = $("#form_" + opts.policyname + " input[type=radio]:checked").val();
    $('body').css('cursor','wait');
    $('input:submit').attr("disabled", true);
    $.ajax({
         type: opts.method,
         url:  opts.action,
         dataType: 'html',
         data: {
           '_method': 'post',
           'groupname': groupname,
           'id': opts.id ,
           'select': select
         },
         success: function(data) {
           $("div#model_" + opts.id + "_name").html(data);
           $("input#model_" + opts.id + "_name").focus();
           $('body').css('cursor','default');
         },
         error: function(data) {
           alert("policy update error!");
         }
       });
    return false;
  });
};


jQuery.fn.addPolicy = function(options) {
  var defaults = {
    method: 'post',
    action: 'policy/',
    trigger_on: 'click'
  };
  var opts = $.extend(defaults, options);
  this.bind(opts.trigger_on, function() {
    var groupname =  opts.groupname;
    var selection = $("#form_" + groupname + " input[type=radio]:checked").val();
    $('body').css('cursor','wait');
    $('input:submit').attr("disabled", true);
    $.ajax({
         type: opts.method,
         url:  opts.action,
         dataType: 'html',
         data: {
           '_method': 'post',
           'id': opts.id,
           'groupname': groupname,
           'selection': selection
         },
         success: function(data) {
           $("div#model_" + opts.id + "_name").html(data);
           $("input#model_" + opts.id + "_name").focus();
           $('body').css('cursor','default');
         },
         error: function(data) {
           alert("add policy error!");
         }
       });
    return false;
  });
};

jQuery.fn.cancelEdit = function(options) {
  var defaults = {
    method: 'get',
    action: 'model/' + options.id + '/name?mode=show',
    trigger_on: 'click'
  };
  var opts = $.extend(defaults, options);
  
  this.bind(opts.trigger_on, function() { 
    $.ajax({
         type: opts.method,
         url:  opts.action,
         dataType: 'html',
         data: {
           '_method': 'get'
         },
         success: function(data) {         
           $("div#model_" + opts.id + "_name").html(data);
         },
         error: function(data) {
           alert("model cancel error!");
         }
       });
    return false;
  });
};

jQuery.fn.saveModel = function(options) {
  var defaults = {
    method: 'put',
    action: 'model/' + options.id,
    trigger_on: 'click'
  };
  var opts = $.extend(defaults, options);
  
  this.bind(opts.trigger_on, function() {  
    var name =  $("input#model_" + opts.id + "_name").val();  
    $.ajax({
         type: opts.method,
         url:  opts.action,
         dataType: 'html',
         data: {
           '_method': 'put',
           'name': name
         },
         success: function(data) {         
           $("div#model_" + opts.id + "_name").html(data);
         },
         error: function(data) {
           alert("model save error!");
         }
       });
    return false;
  });
};


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

$(document).ready(function() {
  $('A[rel="external"]').each(function() {
    $(this).attr('alt', 'Link opens in new window.');
    $(this).attr('title', 'Link opens in new window.');
  });
  $('A[rel="external"]').click(function() {
    window.open($(this).attr('href'));
    return false;
  });
});
