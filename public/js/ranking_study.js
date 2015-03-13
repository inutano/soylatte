$(function(){
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


    d3.csv("data/study_ct.csv", function(error, datab) {
        //dataはindexをkeyとした一列の配列に変換される
        studys = d3.keys(datab[0]);
        studys = studys.slice(0, 5);
        study_vals = d3.values(datab[0]);
        dimensionb = studys.map(function (name, i) {
            return {name: name, val: study_vals[i]}
        });
        dimensionb = dimensionb.slice(0, 5);

        drawBar(dimensionb);
        drawRanking(dimensionb);

    });

    function drawRanking(){
        listb = svg_listb.selectAll(".lists")
                .data(dimensionb)
                .enter()
                .append("g")
                .attr("transform","translate(0, 10)")
                .attr("font-size", 14)
                .attr("fill","#444444")
                .attr("class", "lists")
                .on("click", function(d){showList(d.name)});

        //ランキング表の背景画像をまず作る
        listb.append("rect");

        listb.append("text")
                .attr("y", function(d,i){return i * 22 + 4})
                .attr("x", 25)
                .text(function(d, i){
                    if(i < 5){return d.name};
                })
                .attr("fill", "#444444")
                //背景の矩形のプロパティを取得
                .each(function(d){
                    var bbox = this.getBBox();
                    d.width = bbox.width;
                    d.height = bbox.height;
                    d.y = bbox.y;
                    d.x = bbox.x;
                });

        //ランキング表の背景画像のプロパティを変更
        listb.select("rect")
                .attr({width: function(d){return 14},
                    height: function (d) {return d.height;},
                    fill: function(d,i){return color(i)},
                    x: function(d){return d.x - 25 },
                    y: function(d){return d.y}
                });

    }



    function drawBar(datas){
        var names = datas.map(function(d){return d.name});
        var values = datas.map(function(d){return +d.val});
        x2.rangeBands([0,width]).domain(names);
        y2.range([height, 0]).domain([0,d3.max(values)]);

        //軸をcall
        axisb.call(x2Axis.scale(x2).tickFormat(""));



        //矩形の描画
        bars1b.selectAll("g").data(datas).enter().append("g").append("rect");
        bars1b.selectAll("g").data(datas).exit().remove();
        bars1b.selectAll("rect").data(datas)
                .attr("x", function(d,i){return (i * x2.rangeBand())})
                .attr("y", function(d){return y2(+d.val)})
                .attr("width", x2.rangeBand())
                .attr("height", function (d){
                    return height - y2(+d.val)
                })
                .attr("fill", function(d,i){
                    return color(i);
                })
                .attr({"stroke-width": 2,"stroke":"#ffffff","cursor":"pointer"})
                .attr("class", function(d, i){return  "rect_o" + i})
                .on("click", function(d){
                   showList(d.name)
                });

        //吹き出し部分の矩形描画
        bars2b.selectAll("g").data(datas).enter().append("g").append("rect");
        bars2b.selectAll("g").data(datas).exit().remove();
        bars2b.selectAll("rect").data(datas)
                .attr("x", function(d,i){return (i * x2.rangeBand() + 2)})
                .attr("y", function(d){return y2(d.val)})
                .attr("fill", function(d,i){return color(i)})
                .attr({"rx": 3,"ry": 3,"stroke":"#696969","stroke-width":2,"fill-opacity":"0.25","cursor":"pointer"})
                .attr("width", x2.rangeBand() - 4)
                .attr("height", 15)
                .on("click", function(d){
                   showList(d.name)
                });

        //吹き出し内のテキストを描画
        bars3b.selectAll("g").data(datas).enter().append("g").append("text");
        bars3b.selectAll("g").data(datas).exit().remove();
        bars3b.selectAll("text").data(datas)
                .attr("x", function(d,i){return (i * x2.rangeBand()+ (x2.rangeBand())/2)})
                .attr("y", function(d){return y2(d.val)+ 10})
                .attr({"fill": "#696969","font-size":"12px","cursor":"pointer"})
                .text(function(d){return parseInt(d.val)})
                .attr("text-anchor","middle")
                .on("click", function(d){
                   showList(d.name)
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
    $("#col2_form input:text").on("keypress keyup change", function (e) {
        var query_text = $("#col1_form input:text").val();
        if (e.keyCode == 46 || e.keyCode == 8)
        { //BackspaceやDeltekeyが入力された場合
            if (query_text == "") {
                //検索文字がnullとなった場合ランキングチャートを表示する
                drawBar(dimensionb);
                drawRanking(dimensionb)
            } else {
                d3.json("projects?dimension=organism&query_text=" + query_text, function (error, data) {
                    //文字が入力されている場合jsonを再取得し検索結果によるグラフを表示する
                    drawBar(data);
                    drawRanking(data);
                })
            }
        }else if(query_text != ""){
            //通常に文字が入力されたケースの挙動。jsonを新しい条件で再取得。ただし↑など文字はフィルタすべき。
            d3.json("projects?dimension=organism&query_text=" + query_text, function (error, data) {
                drawBar(data);
                drawRanking(data);
            })
        }
    });

    function showList(q){
        if(q != "total"){
            //window.location = "/lists?org=" + q;
            window.location = "/lists"
        }
    }



});
