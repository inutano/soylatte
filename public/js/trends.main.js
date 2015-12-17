$(document).ready(function(){
  var url = 'cgi-bin/publication2.php',
  url_query,
  val_taxon = "",
  val_type = "",
  val_platform = "";

  $("#get_tabledata").on("click", function(){
    $("#pubtable").fadeOut().delay(200).empty().fadeIn();
    url_query = url + "?type=" + val_type + "&platform=" + val_platform + "&taxon_id=" + val_taxon;
    getjson(url_query);
  });

  $("[name=taxon_id]").change(function(){
    val_taxon = $("#taxon_id option:selected").val();
  });
  $("[name=type]").change(function(){
    var raw_type = $("#type_text option:selected").text();
    val_type = encodeURI(raw_type);
  });
  $("[name=platform]").change(function(){
    var raw_platform = $("#platform_text option:selected").text();
    val_platform = encodeURI(raw_platform);
  });

  getjson(url);

  function getjson(url){
    $.getJSON(url, function(dataset){
      data = dataset.ResultSet.Result;
      YUI().use("datatable", "datasource-get", "datasource-jsonschema", "datatable-datasource","datatable-paginator","datatype-number", function (Y) {
          //var url = "http://sra.dbcls.jp/cgi-bin/publication2.php?",
          var qmyDataSource,
          table;

          myDataSource = new Y.DataSource.Local({
            source: data
          })

          myDataSource.plug(Y.Plugin.DataSourceJSONSchema, {
          schema: {

              resultFields: ["pmid","article_title","journal","vol","issue","page","date","sra_id_orig","sra_id","sra_title"]
            }
          });

          var columns = [
            {
              key : "pmid",
              formatter: ' {value} ',
              allowHTML: true
            },
            {
              key: "article_title"
            },
            {
              key: "journal"
            },
            {
              key: "vol"
            },
            {
              key: "issue"
            },
            {
              key: "page"
            },
            {
              key: "date"
            },
            {
              key: "sra_id_orig"
            },
            {
              key: "sra_id",
              formatter: '{value} ',
              allowHTML: true
            },
            {
              key: "sra_title"
            }

          ]

          table = new Y.DataTable({
            columns: columns,
            sortable: true,
            rowsPerPage: 20,
            paginatorLocation: ['header', 'footer']
          });

          table.plug(Y.Plugin.DataTableDataSource, {
            datasource: myDataSource,
          });

          table.render("#pubtable");

          table.datasource.load();
      });
    });
  }
});
