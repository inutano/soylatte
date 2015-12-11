$(function () {
    Highcharts.setOptions({
	global: {
	    useUTC: false
		}
	});
    });

    $(function () {
        jQuery.getJSON('sra.platform.json', function(data) {
	    var dataLength = data.length;

            for (j = 1; j < 37; j++) {
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
		    renderTo: 'graphPlatform',
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

		tooltip: {
		    shared: false
		},
 
		navigator : {
                    enabled : false
		},

		series: [{
                    name: 'Illumina HiSeq 2500',
		    data: line1,
		    type: 'line',
		    tooltip: {
			yDecimals: 2
		    }
		},{
		    name: 'Illumina HiSeq 2000',
		    data: line2,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
		},{
		    name: 'Illumina HiSeq 1500',
		    data: line3,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
		},{
		    name: 'Illumina HiSeq 1000',
		    data: line4,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
		},{
                    name: 'Illumina MiSeq',
		    data: line5,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
	        },{
		    name: 'Illumina HiScanSQ',
		    data: line6,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
	        },{
		    name: 'Illumina Genome Analyzer IIx',
		    data: line7,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
                },{
                    name: 'Illumina Genome Analyzer II',
		    data: line8,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
                    name: 'Illumina Genome Analyzer',
		    data: line9,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
                },{
		    name: '454 GS FLX Titanium',
		    data: line10,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
                    name: '454 GS FLX+',
		    data: line11,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
                },{
                    name: '454 GS FLX',
		    data: line12,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
		    name: '454 GS 20',
		    data: line13,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
		    name: '454 GS',
		    data: line14,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
                    name: '454 GS Junior',
		    data: line15,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                   } 
                },{
		    name: 'AB SOLiD 5500xl',
		    data: line16,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
                    name: 'AB SOLiD 5500',
		    data: line17,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
		},{
		    name: 'AB 5500xl-W Genetic Analysis System',
		    data: line18,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
                },{
		    name: 'AB 5500xl Genetic Analyzer',
		    data: line19,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
		    name: 'AB 5500 Genetic Analyzer',
		    data: line20,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
                    name: 'AB 3730 Genetic Analyzer',
		    data: line21,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                   } 
                },{
                    name: 'AB 3500xL Genetic Analyzer',
		    data: line22,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
		    name: 'AB SOLiD PI System',
		    data: line23,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
		    name: 'AB SOLiD 4hq System',
		    data: line24,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
                    name: 'AB SOLiD 4 System',
		    data: line25,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                   } 
                },{
                    name: 'AB SOLiD 3 Plus System',
		    data: line26,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
		    name: 'AB SOLiD System 3.0',
		    data: line27,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
		    name: 'AB SOLiD System 2.0',
		    data: line28,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
                    name: 'AB SOLiD System',
		    data: line29,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                   } 
                },{
                    name: 'Complete Genomics',
		    data: line30,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
		    name: 'Helicos HeliScope',
		    data: line31,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
		    name: 'PacBio RS',
		    data: line32,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
		},{
		    name: 'PacBio RS II',
		    data: line33,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
		    }
                },{
                    name: 'Ion Torrent PGM',
		    data: line34,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                   } 
                },{
                    name: 'Ion Torrent Proton',
		    data: line35,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
                },{
		    name: 'unspecified',
		    data: line36,
		    type: 'line',
		    tooltip: {
                        yDecimals: 2
                    }
	        }]
	    });
	});
    });
