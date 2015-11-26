$(function(){
    var type = [];
    var x2 = d3.scale.ordinal();
    var y2 = d3.scale.linear();
    var x2Axis = d3.svg.axis();
    var y2Axis = d3.svg.axis();
    //リスト描画領域を作成
    var svg_listb = d3.select("#col2_list").append("svg")
        .attr("width",250).attr("height", 115);

    //ランキング描画領域を作成
    var svg_bar1b= d3.select("#col2_bars").append("svg")
        .attr("width", 250).attr("height", height + margin.bottom);
    var svg_bar2b = d3.select("#col2_bars").append("svg")
        .attr("width", 250).attr("height", 17);
    var axisb = svg_bar2b.append("g").attr("class", "x axis")
        .attr("transform", "translate(0,2)")
        .style({"stroke-width":"2px","fill":"none","stroke":"Black"});//tickFormat("")を後指定するためtextは描画されない

    //チャート描画用のグループ作成
    var bars1b = svg_bar1b.append("g").attr("class", "bars").attr("transform", "translate(0,30)");
    var bars2b = svg_bar1b.append("g").attr("class","fukidashi").attr("transform", "translate(0,1)");
    var bars3b = svg_bar1b.append("g").attr("class","vals").attr("transform", "translate(0,2)");
    var bars4b = svg_bar1b.append("g").attr("class", "arrows").attr("transform", "translate(0,1)");
    var listbarb = svg_listb.append("g").attr("class", "ranking_bar").attr("transform","translate(0, 10)");
    var listtextb = svg_listb.append("g").attr("class", "ranking_text").attr("transform","translate(0, 10)");


    d3.json("../sra.type.latest.json", function(error, data) {
        //dataはindexをkeyとした一列の配列に変換される
        studys = data.data;
        studys.forEach(function(d){
          d.count = +d.count;
        });
        studys = studys.slice(0, 5);

        drawBar(studys);
        drawRanking(studys);

    });

    function drawRanking(datas){
      listbarb.selectAll("g").data(datas).enter().append("g").append("rect");
      listtextb.selectAll("g").data(datas).enter().append("g").append("text");
      listbarb.selectAll("g").data(datas).exit().remove();
      listtextb.selectAll("g").data(datas).exit().remove();

      //ランキング表の背景画像をまず作る
      listtextb.selectAll("text").data(datas)
          .attr("y", function (d, i) {
              return i * 22 + 4
          })
          .attr("x", 25)
          .text(function (d, i) {
              if (i < 5) {
                  name = decodeURI(d.type)
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
              showList(escape(d.type))
          });

      listbarb.selectAll("rect").data(datas)
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

    function drawBar(datas){
        var names = datas.map(function(d){return d.type});
        var values = datas.map(function(d){return d.count});
        x2.rangeBands([0,width]).domain(names);
        y2.range([height, 0]).domain([0,d3.max(values)]);

        //軸をcall
        axisb.call(x2Axis.scale(x2).tickFormat(""));

        //矩形の描画
        bars1b.selectAll("g").data(datas).enter().append("g").append("rect");
        bars1b.selectAll("g").data(datas).exit().remove();
        bars1b.selectAll("rect").data(datas)
                .attr("x", function(d,i){return (i * x2.rangeBand())})
                .attr("y", function(d){return y2(d.count)})
                .attr("width", x2.rangeBand())
                .attr("height", function (d){
                    return height - y2(d.count)
                })
                .attr("fill", function(d,i){
                    return color(i);
                })
                .attr({"stroke-width": 2,"stroke":"#ffffff","cursor":"pointer"})
                .attr("class", function(d, i){return  "rect_o" + i})
                .on("click", function(d){
                   showList(d.type)
                });

        //吹き出し部分の矩形描画
        bars2b.selectAll("g").data(datas).enter().append("g").append("rect");
        bars2b.selectAll("g").data(datas).exit().remove();
        bars2b.selectAll("rect").data(datas)
                .attr("x", function(d,i){return (i * x2.rangeBand() + 2)})
                .attr("y", function(d){return y2(d.count)})
                .attr("fill", function(d,i){return color(i)})
                .attr({"rx": 3,"ry": 3,"stroke":"#696969","stroke-width":2,"fill-opacity":"0.25","cursor":"pointer"})
                .attr("width", x2.rangeBand() - 4)
                .attr("height", 15)
                .on("click", function(d){
                   showList(d.type)
                });

        //吹き出し内のテキストを描画
        bars3b.selectAll("g").data(datas).enter().append("g").append("text");
        bars3b.selectAll("g").data(datas).exit().remove();
        bars3b.selectAll("text").data(datas)
                .attr("x", function(d,i){return (i * x2.rangeBand()+ (x2.rangeBand())/2)})
                .attr("y", function(d){return y2(d.count)+ 10})
                .attr({"fill": "#696969","font-size":"11px","cursor":"pointer"})
                .text(function(d){return parseInt(d.count)})
                .attr("text-anchor","middle")
                .on("click", function(d){
                   showList(escape(d.type))
                });

        //吹き出しの足を描画
        bars4b.selectAll("g").data(datas).enter().append("g").append("text");
        bars4b.selectAll("g").data(datas).exit().remove();
        bars4b.selectAll("text").data(values)
                .attr("x", function(d,i){return (i * x2.rangeBand()+ (x2.rangeBand())/2)})
                .attr("y", function(d){return y2(d)+ 25})
                .attr("fill", "#696969")
                .text("▼")
                .attr("text-anchor","middle");
    }

    //transition().duration()を設定するとon("click",,)がエラーになるため、再描画するオブジェクトでないものにイベントをわりあてる
    $("#col2_form select").change(function (e) {
        query_type = $("#select_type").val();
        query_type = escape(query_type);
        $("#main .trends select").css("color", "#444444");

        if (query_type == "") {
            //検索文字がnullとなった場合ランキングチャートを表示する
            drawBar(studys);
            drawRanking(studys);
            $("#search_condition ul.type").html("");
        }else if (e.keyCode == 13) {
          showList(query_type);
        }else if(query_type != ""){
            //通常に文字が入力されたケースの挙動。jsonを新しい条件で再取得。ただし↑など文字はフィルタすべき。
            d3.json("http://sra.dbcls.jp/search/data/filter?species=" + query_species + "&type=" + query_type +"&instrument=" + query_platform +"&search_query=" + search_query, function (error, data) {
              qs = "http://sra.dbcls.jp/search/data/filter?species=" + query_species + "&type=" + query_type +"&instrument=" + query_platform +"&search_query=" + search_query;
              datas = [{"type": "total", "count": data.total},{"type": query_type, "count":data.type.count}];
                drawBar(datas);
                drawRanking(datas);
                $("#search_condition ul.type").html("<li>" + unescape(query_type) + "</li>");
                $("#search_condition ul.search_result").html("<li>" + data.mix.count + "</li>");
            })
        }
    });

    function showList(q){
        if(q != "total"){
          window.location = "http://sra.dbcls.jp/search?species=" + query_species +"&type=" + q + "&instrument=" + query_platform +"&search_query=" + search_query;
        }
    }



});
