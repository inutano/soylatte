$(function(){
    margin = {top: 25, bottom: 30, left: 30, right: 50}, width = 235, height = 200;
    color = d3.scale.ordinal().range(["#EB6238", "#f6ad49", "#f8c822", "#f5e56b", "#dccb18"]);
    var organisms = [];
    var organism_vals = [];
    var x1 = d3.scale.ordinal();
    var y1 = d3.scale.linear();
    var x1Axis = d3.svg.axis();
    var y1Axis = d3.svg.axis();
    //リスト描画領域を作成
    var svg_list1 = d3.select("#col1_list").append("svg")
            .attr("width", 250).attr("height", 115);

    //ランキング描画領域を作成
    var svg_bar1 = d3.select("#col1_bars").append("svg")
            .attr("width", 250).attr("height", height + margin.bottom);
    var svg_bar2 = d3.select("#col1_bars").append("svg")
            .attr("width", 250).attr("height", 17);
    var axis1 = svg_bar2.append("g").attr("class", "x axis")
            .attr("transform", "translate(0,2)")
            .style({"stroke-width": "2px", "fill": "none", "stroke": "Black"});//tickFormat("")を後指定するためtextは描画されない

    //チャート描画用のグループ作成
    var bars1 = svg_bar1.append("g").attr("class", "bars").attr("transform", "translate(0,30)");
    var bars2 = svg_bar1.append("g").attr("class", "fukidashi").attr("transform", "translate(0,1)");
    var bars3 = svg_bar1.append("g").attr("class", "vals").attr("transform", "translate(0,2)");
    var bars4 = svg_bar1.append("g").attr("class", "arrows").attr("transform", "translate(0,1)");


    d3.csv("data/organisms_ct.csv", function (error, data) {
        //dataはindexをkeyとした一列の配列に変換される
        organisms = d3.keys(data[0]);
        organisms = organisms.slice(0, 5);
        organism_vals = d3.values(data[0]);
        dimension1 = organisms.map(function (name, i) {
            return {name: name, val: organism_vals[i]}
        });
        dimension1 = dimension1.slice(0, 5);


        drawBar(dimension1); //グラフ部分の描画
        drawList(dimension1); //リスト部分の描画

    });

    function drawList() {
        //ランキングリストの初期描画
        list1 = svg_list1.selectAll(".lists")
                .data(dimension1)
                .enter()
                .append("g")
                .attr("transform", "translate(0, 10)")
                .attr("font-size", 14)
                .attr("fill", "#444444")
                .attr("class", "lists")
                .on("click", function (d) {
                    showList(d.name)
                });

        //ランキング表の背景画像をまず作る
        list1.append("rect");

        list1.append("text")
                .attr("y", function (d, i) {
                    return i * 22 + 4
                })
                .attr("x", 25)
                .text(function (d, i) {
                    //if(i < 5){return String(i+1)+ ' ' + d.name}
                    ////順位を表示しなくて良い気がする
                    if (i < 5) {
                        return d.name
                    }
                    ;
                })
                .attr("fill", "#444444")
            //背景の矩形のプロパティを取得
                .each(function (d) {
                    var bbox = this.getBBox();
                    d.width = bbox.width;
                    d.height = bbox.height;
                    d.y = bbox.y;
                    d.x = bbox.x;
                });

        //ランキング表の背景画像のプロパティを変更
        list1.select("rect")
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

    function drawBar(datas) {
        names = datas.map(function (d) {
            return d.name
        });
        values = datas.map(function (d) {
            return +d.val
        });
        x1.rangeBands([0, width]).domain(names);
        y1.range([height, 0]).domain([0, d3.max(values)]);

        //軸をcall
        axis1.call(x1Axis.scale(x1).tickFormat(""));


        //矩形の描画
        bars1.selectAll("g").data(datas).enter().append("g").append("rect");
        bars1.selectAll("g").data(datas).exit().remove();
        bars1.selectAll("rect").data(datas)
                .attr("x", function (d, i) {
                    return (i * x1.rangeBand())
                })
                .attr("y", function (d) {
                    return y1(+d.val)
                })
                .attr("width", x1.rangeBand())
                .attr("height", function (d) {
                    return height - y1(+d.val)
                })
                .attr("fill", function (d, i) {
                    return color(i);
                })
                .attr({"stroke-width": 2, "stroke": "#ffffff", "cursor": "pointer"})
                .attr("class", function (d, i) {
                    return "rect_o" + i
                })
                .on("click", function (d) {
                    showList(d.name)
                });

        //吹き出し部分の矩形描画
        bars2.selectAll("g").data(datas).enter().append("g").append("rect");
        bars2.selectAll("g").data(datas).exit().remove();
        bars2.selectAll("rect").data(datas)
                .attr("x", function (d, i) {
                    return (i * x1.rangeBand() + 2)
                })
                .attr("y", function (d) {
                    return y1(d.val)
                })
                .attr("fill", function (d, i) {
                    return color(i)
                })
                .attr({
                    "rx": 3,
                    "ry": 3,
                    "stroke": "#696969",
                    "stroke-width": 2,
                    "fill-opacity": "0.25",
                    "cursor": "pointer"
                })
                .attr("width", x1.rangeBand() - 4)
                .attr("height", 15)
                .on("click", function (d) {
                    showList(d.name)
                });

        //吹き出し内のテキストを描画
        bars3.selectAll("g").data(datas).enter().append("g").append("text");
        bars3.selectAll("g").data(datas).exit().remove();
        bars3.selectAll("text").data(datas)
                .attr("x", function (d, i) {
                    return (i * x1.rangeBand() + (x1.rangeBand()) / 2)
                })
                .attr("y", function (d) {
                    return y1(d.val) + 10
                })
                .attr({"fill": "#696969", "font-size": "11px", "cursor": "pointer"})
                .text(function (d) {
                    return parseInt(d.val + "projects")
                })
                .attr("text-anchor", "middle")
                .on("click", function (d) {
                    showList(d.name)
                });

        //吹き出しの足を描画
        bars4.selectAll("g").data(datas).enter().append("g").append("text");
        bars4.selectAll("g").data(datas).exit().remove();
        bars4.selectAll("text").data(values)
                .attr("x", function (d, i) {
                    return (i * x1.rangeBand() + (x1.rangeBand()) / 2)
                })
                .attr("y", function (d) {
                    return y1(d) + 25
                })
                .attr("fill", "#696969")
                .text("▼")
                .attr("text-anchor", "middle");
    }

    //transition().duration()を設定するとon("click",,)がエラーになるため、再描画するオブジェクトでないものにイベントをわりあてる
    $("#col1_form input:text").on("keypress keyup change", function (e) {
        var query_text = $("#col1_form input:text").val();
        if (e.keyCode == 46 || e.keyCode == 8) { //BackspaceやDeltekeyが入力された場合
            if (query_text == "") {
                //検索文字がnullとなった場合ランキングチャートを表示する
                drawBar(dimension1);
                drawList(dimension1);
            } else {
                d3.json("projects?dimension=organism&query_text=" + query_text, function (error, data) {
                    //文字が入力されている場合jsonを再取得し検索結果によるグラフを表示する
                    drawBar(data);
                    drawList(data);
                })
            }
        } else if (query_text != "") {
            //通常に文字が入力されたケースの挙動。jsonを新しい条件で再取得。ただし↑など文字はフィルタすべき。
            d3.json("projects?dimension=organism&query_text=" + query_text, function (error, data) {
                drawBar(data);
                drawList(data);
            })
        }
    });

    function showList(q) {
        if (q != "total") {
            q = escape(q)
            window.location = "http://sra.dbcls.jp/search/search?species=" + q +"&type=&instrument=&search_query=";
        }
    }


});
