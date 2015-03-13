$(function(){
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


    d3.csv("data/platform_ct.csv", function(error, datac) {
        //dataはindexをkeyとした一列の配列に変換される
        platform = d3.keys(datac[0]);
        platform = platform.slice(0, 5);
        platform_vals = d3.values(datac[0]);
        dimensionc = platform.map(function (name, i) {
            return {name: name, val: platform_vals[i]}
        });
        dimensionc = dimensionc.slice(0, 5);

        drawBar(dimensionc);
        drawRanking(dimensionc);

    });

    function drawRanking(dim){
        listc = svg_listc.selectAll(".lists")
                .data(dim)
                .enter()
                .append("g")
                .attr("transform","translate(0, 10)")
                .attr("font-size", 14)
                .attr("fill","#444444")
                .attr("class", "lists")
                .on("click", function(d){showList(d.name)});

        //ランキング表の背景画像をまず作る
        listc.append("rect");

        listc.append("text")
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
        listc.select("rect")
                .attr({width: function(d){return 14},
                    height: function (d) {return d.height;},
                    fill: function(d,i){return color(i)},
                    x: function(d){return d.x - 25 },
                    y: function(d){return d.y}
                });

    }


    function drawBar(dim){
        var names = dim.map(function(d){return d.name});
        var values = dim.map(function(d){return +d.val});
        x3.rangeBands([0,width]).domain(names);
        y3.range([height, 0]).domain([0,d3.max(values)]);

        //軸をcall
        axisc.call(x3Axis.scale(x3).tickFormat(""));

        //矩形の描画
        bars1c.selectAll("g").data(dim).enter().append("g").append("rect");
        bars1c.selectAll("g").data(dim).exit().remove();
        bars1c.selectAll("rect").data(dim)
                .attr("x", function(d,i){return (i * x3.rangeBand())})
                .attr("y", function(d){return y3(+d.val)})
                .attr("width", x3.rangeBand())
                .attr("height", function (d){
                    return height - y3(+d.val)
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
        bars2c.selectAll("g").data(dim).enter().append("g").append("rect");
        bars2c.selectAll("g").data(dim).exit().remove();
        bars2c.selectAll("rect").data(dim)
                .attr("x", function(d,i){return (i * x3.rangeBand() + 2)})
                .attr("y", function(d){return y3(d.val)})
                .attr("fill", function(d,i){return color(i)})
                .attr({"rx": 3,"ry": 3,"stroke":"#696969","stroke-width":2,"fill-opacity":"0.25","cursor":"pointer"})
                .attr("width", x3.rangeBand() - 4)
                .attr("height", 15)
                .on("click", function(d){
                   showList(d.name)
                });

        //吹き出し内のテキストを描画
        bars3c.selectAll("g").data(dim).enter().append("g").append("text");
        bars3c.selectAll("g").data(dim).exit().remove();
        bars3c.selectAll("text").data(dim)
                .attr("x", function(d,i){return (i * x3.rangeBand()+ (x3.rangeBand())/2)})
                .attr("y", function(d){return y3(d.val)+ 10})
                .attr({"fill": "#696969","font-size":"12px","cursor":"pointer"})
                .text(function(d){return parseInt(d.val)})
                .attr("text-anchor","middle")
                .on("click", function(d){
                   showList(d.name)
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
        var query_text = $("#col1_form input:text").val();
        if (e.keyCode == 46 || e.keyCode == 8)
        { //BackspaceやDeltekeyが入力された場合
            if (query_text == "") {
                //検索文字がnullとなった場合ランキングチャートを表示する
                drawBar(dimensionc);
                drawRanking(dimensionc);
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
