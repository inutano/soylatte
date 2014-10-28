# project: SoyLatte

formerly Kusarinoko; better search and browse for [Sequence Read Archive](http://en.wikipedia.org/wiki/Sequence_Read_Archive).

## Quick start

### Faceted Search (drilldown)

1. Go to [sra.dbcls.jp/search](http://sra.dbcls.jp/search)
2. Choose types of Species/Study/Sequencer
3. Click "submit condition"
4. You'll see donut plots showing the number of matched data
5. Click "view all" to browse all matched projects
6. Or search by any keyword(s) in upper-right textbox to reduce the number of results
7. You'll see a table of matched projects
8. Click column name to sort, type keywords in textbox to narrow-down
9. Click project id to browse details (may take time, wait a minute)
10. You'll see the summary of the project, details of related articles (if they exist), and tables of sequencing runs and samples
12. Click run id to browse sequencing quality
13. Click sample id to see details below
14. Click "TSV" or "JSON" to download a table
15. Click "FTP" to toggle download paths

### Fulltext Search

1. Go to [sra.dbcls.jp/search](http://sra.dbcls.jp/search)
2. Type any keyword(s) in textbox on the right and click "search"
3. Follow instruction above from 7 

## Features

- Faceted search using metadata (described by submitter, possibly imperfect)
- Fulltext search using metadata and related pubmed/pmc articles
- Sequencing quality browser (thx Simon for developing [FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/)!)
- Result table export, tsv or json format
- Programmatic search and access
- Cute Icons (thx [Font Awesome](http://fontawesome.io)!)

## Notes

- Search results does **NOT** include entries that have already been suppressed/withdrawn
- Pairs of SRA ID and Pubmed ID are from DB of [DBCLS SRA Publication Search](http://sra.dbcls.jp/cgi-bin/publication.cgi)
    - Please [notify us](support@dbcls.rois.ac.jp) if you found any missing pair
- Calculation of sequencing quality can delay

## Contribution

[inutano@twitter.com](http://twitter.com/inutano)

## License

"THE BEER-WARE LICENSE" (Revision 42):
<inutano@gmail.com> is contributing to this project. As long as you retain this notice you can do whatever you want with this stuff. If 
we meet some day, and you think this stuff is worth it, you can buy me a beer in return. Tazro Inutano Ohta
