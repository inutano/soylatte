$(function() {
    $("#tableType tbody").html("");

    $.getJSON("./sra.type.latest.json", function(stats) {
	$(stats.data).each(function(i) {
	    i++;
//	    if (i <= 10) {
	    $('<tr>'+
	      '<td>'+
  	        '<a href="/cgi-bin/studylist.cgi?type='+
                   this.type+'">'+
	           this.type+
	        '</a>'+
	      '</td>'+
	      '<td>'+this.count+'</td>'+
	      '</tr>').appendTo('#tableType tbody');
//	    }
	});
//	if (stats.data.length > 10) {
//	    $('<tr><td>...</td><td><br></td></tr>').appendTo('#tablePlatform tbody');
//	}
	$('<tr><td class="total">Total</td><td class="total">'+stats.total+'</td></tr>').appendTo('#tableType tbody');
    });
});
