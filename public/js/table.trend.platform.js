$(function() {
    $("table.tbl tbody").html("");

    $.getJSON("./sra.platform.latest.json", function(stats) {
	$(stats.data).each(function(i) {
	    i++;
//	    if (i <= 10) {
	    $('<tr>'+
	      '<td>'+
  	        '<a href="/search/filter?species=&type=&instrument='+
                   this.platform+'">'+
	           this.platform+
	        '</a>'+
	      '</td>'+
	      '<td>'+this.count+'</td>'+
	      '</tr>').appendTo('#tablePlatform tbody');
//	    }
	});
//	if (stats.data.length > 10) {
//	    $('<tr><td>...</td><td><br></td></tr>').appendTo('#tablePlatform tbody');
//	}
	$('<tr><td class="total">Total</td><td class="total">'+stats.total+'</td></tr>').appendTo('#tablePlatform tbody');
    });
});
