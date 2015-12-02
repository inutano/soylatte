// onload
$(function(){
  loadImages();
})

// functions
// Loading fastqc images

function loadImages(){
  startLoading();
  var readId = window.location.href.split("/")[4];
  var runId = readId.split("/")[0];
  $.ajax({
    url: "/data/fastqc?runid=" + runId,
    type: 'GET',
    dataType: 'json',
  }).done(function(json){
    var fastqc_dirs_url = json;
    var matched = fastqc_dirs_url.filter(function(val){
      return new RegExp(readId+"_fastqc").test(val);
    });
    var dir_url = matched[0];
    putQualityInformation(readId, runId, dir_url);
    removeLoading();
  });
}

function putQualityInformation(readId, runId, dir_url){
  putEntryIds(readId, runId)
  putQualitySummary(dir_url);
  putQualityImages(dir_url);
}

function putEntryIds(readId, runId){
  $("h3#readId").text(readId);
  $("a.linkoutDDBJ").attr("href", "http://trace.ddbj.nig.ac.jp/DRASearch/run?acc="+runId);
  $("a.linkoutEBI").attr("href", "http://www.ebi.ac.uk/ena/data/view/"+runId);
}

function putQualitySummary(dir_url){
  $.ajax({
    url: "/data/fastqc_data?url=" + dir_url,
    type: 'GET',
    dataType: 'text',
  }).done(function(data){
    var summary = parseQualitySummary(data);
    // embed into html
    $("td#fileType").text(summary["fileType"]);
    $("td#encoding").text(summary["encoding"]);
    $("td#totalSequences").text(summary["totalSequences"]);
    $("td#sequenceLength").text(summary["sequenceLength"]);
    $("td#percentGC").text(summary["percentGC"]);
  });
}

function parseQualitySummary(data){
  return {
    fileType: parseQCData(data, "File type"),
    encoding: parseQCData(data, "Encoding"),
    totalSequences: parseQCData(data, "Total Sequences"),
    sequenceLength: parseQCData(data, "Sequence length"),
    percentGC: parseQCData(data, "%GC")
  };
}

function parseQCData(data, pattern){
  var dataArray = data.split("\n")
  var matched = dataArray.filter(function(val){
    return new RegExp(pattern).test(val);
  });
  return matched[0].split("\t")[1];
}

function putQualityImages(url){
  var images = qualityImages(url);
  // embed into html
  $("img.perBaseQuality").attr("src", images["perBaseQuality"]);
  $("img.perSequenceQuality").attr("src",images["perSequenceQuality"]);
  $("img.perBaseSequenceContent").attr("src",images["perBaseSequenceContent"]);
  $("img.perSequenceGCContent").attr("src",images["perSequenceGCContent"]);
  $("img.perBaseNContent").attr("src",images["perBaseNContent"]);
  $("img.sequenceLengthDistribution").attr("src",images["sequenceLengthDistribution"]);
  $("img.duplicationLevels").attr("src",images["duplicationLevels"]);
  $("img.kmerProfiles").attr("src",images["kmerProfiles"]);
}

function qualityImages(url){
  var base = url + "/Images/";
  return {
    duplicationLevels: base + "duplication_levels.png",
    perBaseGCContent: base + "per_base_gc_content.png",
    perBaseQuality: base + "per_base_quality.png",
    perSequenceGCContent: base + "per_sequence_gc_content.png",
    sequenceLengthDistribution: base + "sequence_length_distribution.png",
    kmerProfiles: base + "kmer_profiles.png",
    perBaseNContent: base + "per_base_n_content.png",
    perBaseSequenceContent: base + "per_base_sequence_content.png",
    perSequenceQuality: base + "per_sequence_quality.png"
  };
}

function putImages(images_url){
  var target = $(".sequence_quality")
  $.each(images_url, function(i, url){
    var image = $("<img>").attr("src",url).attr("width",350)
    var alink = $("<a>").attr("href",url).append(image).append("</a>")
    var title = url.split("/")[9];
    var head = $("<h4>").append(title).append("</h4>");
    $("<div>")
      .attr("class", "col-md-3")
      .append(head)
      .append(alink)
      .append("</div>")
      .appendTo(target)
  });
}

function startLoading(){}
function removeLoading(){}
