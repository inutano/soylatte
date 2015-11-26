$(function () {
    Highcharts.setOptions({
	global: {
	    useUTC: false
		}
	});
    });

    $(function () {
        jQuery.getJSON('sra.type.json', function(data) {
	    var dataLength = data.length;

            for (j = 1; j < 16; j++) {
                eval("var line" + j + " = []");
 
		for (var i = 0; i < dataLength; i++) {
		    eval( "line" + j + ".push([" +
	                      "data[i][0]," +
		              "data[i]["+j+"]" +
		          "])");
		}
	    }

	    windowchart = new Highcharts.StockChart({
		chart: {
		    renderTo: 'graphType',
                },
 
		scrollbar: {
		    enabled: false
		},
 
		rangeSelector: {
		    selected: 5
		},

		title: {
                    text: ''
		},

		credits: {
                    text: ''
		},

		xAxis: {
	            labels: {
		        format: '{value:%y-%m}',
			rotation: -45,
		    },
		    tickPixelInterval: 40
		},

		yAxis: {
		    lineWidth: 0,
		    offset: 10,
		    min: 0,
		    labels: {
		       align: 'right'
		    }
		},
 
		legend: {
	            width: 201,
		    enabled: true,
		    align: 'right',
		    layout: 'vertical',
		    verticalAlign: 'top',
		    y: 100,
                },
 
		navigator : {
                    enabled : false
		},
 
		series: [{
                    name: 'Whole Genome Seq',
		    data: line1,
		    type: 'line',
		    tooltip: {
			yDecimals: 2
		    }
		},{
		    name: 'Transcriptome Analysis',
		    data: line2,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
		},{
		    name: 'Metagenomics',
		    data: line3,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
		},{
                    name: 'Epigenetics',
		    data: line4,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
	        },{
		    name: 'Reseq',
		    data: line5,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
	        },{
		    name: 'Other',
		    data: line6,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
                },{
                    name: 'RNASeq',
		    data: line7,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
                    name: 'Population Genomics',
		    data: line8,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
                },{
		    name: 'Gene Reg Study',
		    data: line9,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
                    name: 'Cancer Genomics',
		    data: line10,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
                },{
                    name: 'Exome Seq',
		    data: line11,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
		    name: 'Synthetic Genomics',
		    data: line12,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
		    name: 'Forensic or Paleo-genomics',
		    data: line13,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
                    name: 'Pooled Clone Seq',
		    data: line14,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                   } 
                },{
		    name: 'TOTAL',
		    data: line15,
		    type: 'line',
		    lineWidth: 4,
		    tooltip: {
                        yDecimals: 2
                    }
	        }]
	    });
	});
    });
