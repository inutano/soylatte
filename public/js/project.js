$(function(){
  embedLinkToRunID();
});

function embedLinkToRunID(){
  $.each($("a.run"), function(i){
    var alink = $(this);
    var readId = alink.text();
    var url = "/data/fastqc?mode=availablity&runid=" + readId;
    $.ajax({
      url: url,
      type: 'GET',
      dataType: 'text'
    }).done(function(bool){
      alink.attr("href", "/view/" + readId);
    });
  });
}
