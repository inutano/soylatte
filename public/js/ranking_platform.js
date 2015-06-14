$(function(){
    var platform = []
    var x3 = d3.scale.ordinal();
    var y3 = d3.scale.linear();
    var x3Axis = d3.svg.axis();
    var y3Axis = d3.svg.axis();
    //リスト描画領域を作成
    var svg_listc = d3.select("#col3_list").append("svg")
        .attr("width",250).attr("height", 115);

    //ランキング描画領域を作成
    var svg_bar1c= d3.select("#col3_bars").append("svg")
        .attr("width", 250).attr("height", height + margin.bottom);
    var svg_bar2c = d3.select("#col3_bars").append("svg")
        .attr("width", 250).attr("height", 17);
    var axisc = svg_bar2c.append("g").attr("class", "x axis")
        .attr("transform", "translate(0,2)")
        .style({"stroke-width":"2px","fill":"none","stroke":"Black"});//tickFormat("")を後指定するためtextは描画されない

    //チャート描画用のグループ作成
    var bars1c = svg_bar1c.append("g").attr("class", "bars").attr("transform", "translate(0,30)");
    var bars2c = svg_bar1c.append("g").attr("class","fukidashi").attr("transform", "translate(0,1)");
    var bars3c = svg_bar1c.append("g").attr("class","vals").attr("transform", "translate(0,2)");
    var bars4c = svg_bar1c.append("g").attr("class", "arrows").attr("transform", "translate(0,1)");
    var listbarc = svg_listc.append("g").attr("class", "ranking_bar").attr("transform","translate(0, 10)");
    var listtextc = svg_listc.append("g").attr("class", "ranking_text").attr("transform","translate(0, 10)");


    d3.json("http://sra.dbcls.jp/sra.platform.latest.json", function(error, data) {
        //dataはindexをkeyとした一列の配列に変換される
        platform = data.data;
        platform.forEach(function(d){
          d.count = +d.count
        });
        platform = platform.slice(0, 5);

        drawBar(platform);
        drawRanking(platform);

    });

    function drawRanking(datas){
      listbarc.selectAll("g").data(datas).enter().append("g").append("rect");
      listtextc.selectAll("g").data(datas).enter().append("g").append("text");
      listbarc.selectAll("g").data(datas).exit().remove();
      listtextc.selectAll("g").data(datas).exit().remove();

      //ランキング表の背景画像をまず作る
      listtextc.selectAll("text").data(datas)
          .attr("y", function (d, i) {
              return i * 22 + 4
          })
          .attr("x", 25)
          .text(function (d, i) {
              if (i < 5) {
                  name = decodeURI(d.platform)
                  return name
              };
          })
          .attr("fill", "#444444")
      //背景の矩形のプロパティを取得
          .each(function (d) {
              var bbox = this.getBBox();
              d.width = bbox.width;
              d.height = bbox.height;
              d.y = bbox.y;
              d.x = bbox.x;
          })
          .on("click", function (d) {
              showList(d.platform)
          });

      listbarc.selectAll("rect").data(datas)
              .attr({
                  width: function (d) {
                      return 14
                  },
                  height: function (d) {
                      return d.height;
                  },
                  fill: function (d, i) {
                      return color(i)
                  },
                  x: function (d) {
                      return d.x - 25
                  },
                  y: function (d) {
                      return d.y
                  }
              });
    }


    function drawBar(dim){
        var names = dim.map(function(d){return d.platform});
        var values = dim.map(function(d){return d.count});
        x3.rangeBands([0,width]).domain(names);
        y3.range([height, 0]).domain([0,d3.max(values)]);

        //軸をcall
        axisc.call(x3Axis.scale(x3).tickFormat(""));

        //矩形の描画
        bars1c.selectAll("g").data(dim).enter().append("g").append("rect");
        bars1c.selectAll("g").data(dim).exit().remove();
        bars1c.selectAll("rect").data(dim)
                .attr("x", function(d,i){return (i * x3.rangeBand())})
                .attr("y", function(d){return y3(d.count)})
                .attr("width", x3.rangeBand())
                .attr("height", function (d){
                    return height - y3(d.count)
                })
                .attr("fill", function(d,i){
                    return color(i);
                })
                .attr({"stroke-width": 2,"stroke":"#ffffff","cursor":"pointer"})
                .attr("class", function(d, i){return  "rect_o" + i})
                .on("click", function(d){
                   showList(d.platform)
                });

        //吹き出し部分の矩形描画
        bars2c.selectAll("g").data(dim).enter().append("g").append("rect");
        bars2c.selectAll("g").data(dim).exit().remove();
        bars2c.selectAll("rect").data(dim)
                .attr("x", function(d,i){return (i * x3.rangeBand() + 2)})
                .attr("y", function(d){return y3(d.count)})
                .attr("fill", function(d,i){return color(i)})
                .attr({"rx": 3,"ry": 3,"stroke":"#696969","stroke-width":2,"fill-opacity":"0.25","cursor":"pointer"})
                .attr("width", x3.rangeBand() - 4)
                .attr("height", 15)
                .on("click", function(d){
                   showList(d.platform)
                });

        //吹き出し内のテキストを描画
        bars3c.selectAll("g").data(dim).enter().append("g").append("text");
        bars3c.selectAll("g").data(dim).exit().remove();
        bars3c.selectAll("text").data(dim)
                .attr("x", function(d,i){return (i * x3.rangeBand()+ (x3.rangeBand())/2)})
                .attr("y", function(d){return y3(d.count)+ 10})
                .attr({"fill": "#696969","font-size":"11px","cursor":"pointer"})
                .text(function(d){return parseInt(d.count)})
                .attr("text-anchor","middle")
                .on("click", function(d){
                   showList(d.platform)
                });

        //吹き出しの足を描画
        bars4c.selectAll("g").data(dim).enter().append("g").append("text");
        bars4c.selectAll("g").data(dim).exit().remove();
        bars4c.selectAll("text").data(values)
                .attr("x", function(d,i){return (i * x3.rangeBand()+ (x3.rangeBand())/2)})
                .attr("y", function(d){return y3(d)+ 25})
                .attr("fill", "#696969")
                .text("▼")
                .attr("text-anchor","middle");
    }

    //transition().duration()を設定するとon("click",,)がエラーになるため、再描画するオブジェクトでないものにイベントをわりあてる
    $("#col3_form input:text").on("keypress keyup change", function (e) {
        //console.log("input");
        query_platform = $("#col3_form input:text").val();
        query_platform = escape(query_platform);
        //query_platform = escape(query_platform);
        if (e.keyCode == 46 || e.keyCode == 8)
        { //BackspaceやDeltekeyが入力された場合
            if (query_platform == "") {
                //検索文字がnullとなった場合ランキングチャートを表示する
                drawBar(platform);
                drawRanking(platform);
                $("#search_condition ul.platform").html("");
                $("#search_condition ul.search_result").html("");
            } else {
                d3.json("http://sra.dbcls.jp/search/data/filter?species=" + query_species + "&type=" + query_type +"&instrument=" + query_platform +"&search_query=" + search_query, function (error, data) {
                    //文字が入力されている場合jsonを再取得し検索結果によるグラフを表示する
                    datas = [{"platform": "total", "count": data.total},{"platform": query_platform, "count":data.instrument.count}];
                    drawBar(datas);
                    drawRanking(datas);
                    $("#search_condition ul.platform").html("<li>" + unescape(query_platform) + "</li>");
                    $("#search_condition ul.search_result").html("<li>" + data.mix.count + "</li>");
                })
            }
        }else if (e.keyCode == 13) {
          showList(query_platform);
        }else if(query_platform != ""){
            //通常に文字が入力されたケースの挙動。jsonを新しい条件で再取得。ただし↑など文字はフィルタすべき。
            d3.json("http://sra.dbcls.jp/search/data/filter?species=" + query_species + "&type=" + query_type +"&instrument=" + query_platform +"&search_query=" + search_query, function (error, data) {
                datas = [{"platform": "total", "count": data.total},{"platform": query_platform, "count":data.instrument.count}];
                drawBar(datas);
                drawRanking(datas);
                $("#search_condition ul.platform").html("<li>" + unescape(query_platform) + "</li>");
                $("#search_condition ul.search_result").html("<li>" + data.mix.count + "</li>");
            })
        }
    });

    function showList(q){
        if(q != "total"){
          window.location = "http://sra.dbcls.jp/search?species=" + query_species +"&type=" + query_type + "&instrument=" + q +"&search_query=" + search_query;
        }
    }


});
